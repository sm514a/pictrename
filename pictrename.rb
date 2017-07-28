#!/usr/bin/ruby

=begin
Date: 2013-01-03
Auth: Shunsuke
=end


require 'FileUtils'

class PngExif
  attr_accessor :data
  def initialize(file)
    string = `./exiftool.exe "#{file}"`
    @data = {}
    string.each_line do |line|
      key, val = line.chomp.split(/\s+:\s+/, 2)
#      key.gsub!(/\s+/, '')
#      val.gsub!(/\s+/, '')
      @data[key] = val
    end
  end
  
  def date_time_original
    str = @data["File Modification Date/Time"]
    array = str[0..-7].split(/[: ]/) + [str[-6..-1]]
    Time.new(*array) + 60 * 60 * 9
  end
  
  def model
    @data["Model"] || @data["Camera Model Name"] || "IMG"
  end

end

class MovExif
  attr_accessor :data
  def initialize(file)
    string = `./exiftool.exe #{file}`
    @data = {}
    string.each_line do |line|
      key, val = line.chomp.split(/\s+:\s+/, 2)
#      key.gsub!(/\s+/, '')
#      val.gsub!(/\s+/, '')
      @data[key] = val
    end
  end
  
  def date_time_original
    date = Time.new(*@data["Modify Date"].split(/[: ]/))
    if @data["File Type"] == "MOV"
      case model
      when MODEL_DEFAULT, "TG-4"
      else 
        date += 60 * 60 * 9
      end
    else
      case model
      when MODEL_DEFAULT
        date += 60 * 60 * 9
      else 
      end
    end
    date
  end

  MODEL_DEFAULT = "IXYxxxx"  #mode名が見つからなかった場合のデフォルト
  def model
    @data["Model"] || @data["Camera Model Name"] || MODEL_DEFAULT
  end
  
end

class ExifInfo
  MODEL_ALIAS = {
    "Canon PowerShot S110" => "PwrShot", 
    "iPhone 7" =>             "iPhone7",
    "iPhone 5" => "iPhone5",
    "TG-4" =>     "OlymTG4",
    "Canon IXY DIGITAL 930 IS" => "IXY93is",
  }
  
  MetaInfoType = {
    ".PNG" => PngExif,
  }
  
  attr_accessor :exif
  def initialize(file)
    @file = file
    cls = MetaInfoType[ext] || MovExif
    @exif = cls.new(file)
  end
  
  def ext
    File.extname(@file).upcase
  end
  
  def date
    @exif.date_time_original
  end

  def model
    model = @exif.model.gsub(/\s+$/, '')
    MODEL_ALIAS[model] || model
  end

  def ordinary_name
    name = date.strftime("%Y_%m_%d/#{model}_%H%M%S")
    if @exif.data["Burst UUID"]
      name += "_B#{@exif.data["Sub Sec Time Original"]}"
    end
    name
  end

  def arranged_file_name(dir="")
    basename = ordinary_name
    name = "#{dir}/#{basename+ext}"
    if File.exist?(name) 
      basename += 'a'
      while File.exist?("#{dir}/#{basename+ext}") do 
        basename.succ!
      end
      name = "#{dir}/#{basename+ext}"
    end
    name
  end
  
end

  
#DIR_FROM = "../example"
#DIR_FROM = ["../example","../example2"]
#DIR_FROM = ["../example"]
#DIR_FROM = ["/cygdrive/g/picture/to_be_recorded/2012_05_11"]
#DIR_FROM = ["/cygdrive/g/picture/to_be_recorded/2012_05_19"]
#DIR_FROM = ["g:/picture/to_be_recorded/2012_05_19"]

# DIR_FROM = [
# "G:/picture/to_be_recorded/2012_09_02", 
# "G:/picture/to_be_recorded/2012_08_18", 
# "G:/picture/to_be_recorded/2012_08_19", 
# "G:/picture/to_be_recorded/2012_08_20", 
# "G:/picture/to_be_recorded/2012_08_23", 
# "G:/picture/to_be_recorded/2012_08_24", 
# "G:/picture/to_be_recorded/2012_08_26", 
# "G:/picture/to_be_recorded/2012_08_27", 
# "G:/picture/to_be_recorded/2012_09_01", 
# ]

DIR_FROM = ["G:/a"]
#DIR_FROM = ["G:/a/iphone/20150220_DCMI/884VVBVQ/"]
DIR_TO = "G:/sorted_to_be_saved"


copy = false
dryrun = false
opr = copy ? "cp" : "mv"

def make_dir_unless_exist(dir)
  FileUtils.mkdir_p(dir) unless File.exist?(dir)
end

#make_dir_if_not_exist(DIR_TO)

report_name = Time.now.strftime("#{DIR_TO}/REPORT_%Y%m%d.txt")

SUPPORTED = ["JPG","MOV","PNG"]
REMOVE_PATTERN = /\b(ZbThumbnail.info)$/

date_till = Time.new(2018,10,16)   #これ以降に取得されたデータはそのまま

SUPPORTED_FILE_PATTERN = /\.(#{SUPPORTED.join("|")})$/i

time_start = Time.now

Array(DIR_FROM).each do |dir_from|

  files = Dir.glob("#{dir_from}/**/*")
  #files = ["example/PA010020.JPG", "example/MVI_3976.MOV", "example/IMG_0001.MOV"]
  #files = ["example/PA010020.JPG"]
  
  files.each do |file|
    
    begin
      puts file

      if File.directory?(file)
        #puts "#{file}...skipped!"
        next 
      end
      
      if file =~ REMOVE_PATTERN
        puts "To be removed: #{file} ... skipped"
        if dryrun
        else
            File.delete file
        end
        next
      end
      
      unless file.ascii_only?
        puts "Illegal filname: #{file} ... skipped"
        next 
      end
      
      if file =~ / /
        puts "Illegal filname: #{file} ... skipped"
        next 
      end
      
      unless file =~ SUPPORTED_FILE_PATTERN
        puts "Unknown file format: #{file} ... ignored"
        next 
      end
      
      exifinfo = ExifInfo.new(file)
      next unless exifinfo.date < date_till
      newfile = exifinfo.arranged_file_name(DIR_TO)
      make_dir_unless_exist(File.dirname(newfile))
      cmd = "#{opr} #{file} #{newfile}"
      open(report_name, "a"){|report| report.puts "(#{exifinfo.date < date_till})#{cmd}" }
      
      if dryrun
      else
          system cmd 
      end
      
    rescue => e
      puts "rescued!"
      puts e
      next
    end
  end
end


puts "#{Time.now - time_start}sec elapsed"


