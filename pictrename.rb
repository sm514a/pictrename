#!/usr/bin/ruby

require 'FileUtils'


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
      when MODEL_DEFAULT

      else 
        date += 60 * 60 * 9
      end
    else
      case model
      when "TG-4", "Canon PowerShot S110", "iPhone 7", "iPhone 5"
        #何もしない
      else 
        date += 60 * 60 * 9
      end
    end
    date
  end

  MODEL_DEFAULT = "IXYx"  #mode名が見つからなかった場合のデフォルト
  def model
    @data["Model"] || @data["Camera Model Name"] || MODEL_DEFAULT
  end
  
end

class ExifInfo
  MODEL_ALIAS = {
    "Canon PowerShot S110" => "PwrShot", 
    "iPhone 7" =>             "iPhone7",
    "iPhone 5" => "iPhone5",
    "TG-4" =>     "TG4",
  }
  
  # DATACLASS = {
  #   ".MOV" => MovExif, 
  #   ".JPG" => EXIFR::JPEG, 
  # }
  
  attr_accessor :exif
  def initialize(file)
    @file = file
    @exif = MovExif.new(file)
  end
  
  def ext
    File.extname(@file)
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
    name += ext
  end

  def arranged_file_name(dir="")
    name = "#{dir}/#{ordinary_name}"
    while File.exist?(name) do 
      #Pending
    end
    name
  end
  
end
  
#DIR_FROM = "./example_2"
DIR_FROM = "../example"
DIR_TO = "../to"
                        
copy = true
dryrun = true
opr = copy ? "cp" : "mv"

def make_dir_unless_exist(dir)
  FileUtils.mkdir_p(dir) unless File.exist?(dir)
end

#make_dir_if_not_exist(DIR_TO)

REPORT = "REPORT.txt"

# e = ExifInfo.new("./example/IMG_0026.MOV")
# p e.exif.data

date_till = Time.new(2016,10,16)   #これ以降に取得されたデータはそのまま


open(REPORT, "w"){|report|
  Array(DIR_FROM).each do |dir_from|
  
    files = Dir.glob("#{dir_from}/**/*")
    #files = ["example/PA010020.JPG", "example/MVI_3976.MOV", "example/IMG_0001.MOV"]
    #files = ["example/PA010020.JPG"]
    
    files.each do |file|
      next if File.directory?(file)
      exifinfo = ExifInfo.new(file)
      next unless exifinfo.date < date_till
      newfile = exifinfo.arranged_file_name(DIR_TO)
      cmd = "#{opr} #{file} #{newfile}"
      report.puts "(#{exifinfo.date < date_till})#{cmd}"
      if dryrun
      else
          make_dir_unless_exist(File.dirname(newfile))
          system cmd 
      end
    end
    
  end
}


