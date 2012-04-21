#!/usr/bin/env ruby

require 'yaml'

class Msync

  def initialize
    @config = YAML::load(File.open("#{ENV['HOME']}/.msync"))
  end

  def disk_mount
    unless File.exists?("/Volumes/#{@config[:disk]}")
      puts "Mirror disk not mounted...mounting it"
      Kernel.system('diskutil', 'mountDisk', @config[:disk])
    end
  end

  def do_rsyncs
    disk_mount
    @config[:mtype][:rpm][:syncer][:rsync][:mirrors].each do |m|
      screened(m[0], "rsync -azPH --delete --delete-before --exclude '.*' rsync://#{@config[:source]}/#{m[0]} #{@config[:mtype][:rpm][:staging]}/mirrors/#{@config[:source]}/#{m[0]}")
    end
  end

  def do_rsyncs_special
    disk_mount
    rsync_include_config
  end

  def rsync_include_config
    contents = %x['rsync' "rsync://#{@config[:source]}/#{m[0]}"]
    files = contents.each_line.reject do |line| line.match(/^l|^d/) end
  end

  def do_apts
    disk_mount
    apt_mirror_config
    screened('apt-mirrors', "apt-mirror /tmp/mirror.list_#{$$}")
  end

  def apt_mirror_config
    template = "set base_path #{@config[:mtype][:apt][:staging]}" << "\n"
    template << 'set mirror_path $base_path/mirrors' << "\n"
    template << 'set skel_path   $base_path/skel' << "\n"
    template << 'set var_path    $base_path/var' << "\n"
    template << 'set cleanscript $var_path/clean.sh' << "\n"
    template << 'set defaultarch i386' << "\n" << "\n"

    @config[:mtype][:apt][:syncer][:"apt-mirror"][:mirrors].each do |m|
      m[1][:releases].each do |r|
        template << "deb http://#{@config[:source]}/#{m[0]} #{r[0]} #{r[1][:components].join(' ')}" << "\n" +
                    "deb-amd64 http://#{@config[:source]}/#{m[0]} #{r[0]} #{r[1][:components].join(' ')}" << "\n"  +
                    "deb-src http://#{@config[:source]}/#{m[0]} #{r[0]} #{r[1][:components].join(' ')}" << "\n\n"
      end
      template << "clean http://#{@config[:source]}/#{m[0]}\n\n"
    end
    File.open("/tmp/mirror.list_#{$$}", 'w') do |f| f.write(template) end
  end

  def screened(mirror, command)
    Kernel.system("screen -S #{mirror} -d -m #{command}")
  end
end
