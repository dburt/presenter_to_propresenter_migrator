#!/usr/bin/env ruby
#
# Convert song files from Presenter (http://presentersoftware.com/)
# to ProPresenter 5 format.
#
# Here are the steps:
#   0) set working directory to the location of the Presenter files ("*.txt")
#   1) run script with -1 argument to convert Presenter files to plain_text/*.txt
#   2) import plain text files into ProPresenter 5
#   3) copy ProPresenter 5 files into propresenter_xml directory
#   4) run script with -2 argument to add metadata in modified_xml/*.pro5
#   5) delete imported files from ProPresenter 5
#   6) import modified_xml/*.pro5 into ProPresenter 5
#
# Author: Dave Burt <dave@burt.id.au>
# Created: 6 May 2014
#

require 'stringio'
require 'rubygems'
require 'nokogiri'
require 'pry'

Encoding.default_external = Encoding::ISO_8859_1
Encoding.default_internal = Encoding::ISO_8859_1

class PresenterSong
  attr_reader :title, :artist, :info, :key, :sequence, :slides

  def initialize(string)
    @slides = []
    string.encode('UTF-8').each_line.each_with_index do |line, i|
      if @header_complete
        parse_body_line line, i
      else
        parse_header_line line
      end
    end
    @slides.delete_if {|slide| slide.empty? }
  end

  def to_s(format = :plain_text)
    send "to_s_#{format}"
  end

  private

  def to_s_plain_text
    io = StringIO.new
    slides.each do |slide|
      io.puts slide.body.strip
      io.puts
    end
    io.string
  end

  def to_s_ccli_text
    io = StringIO.new
    io.puts title
    io.puts
    slides.each do |slide|
      if slide.number =~ /\d/
        io.puts "Verse #{slide.number}"
      else
        io.puts "#{slide.number} 1"
      end
      io.puts slide.body.strip
      io.puts
      io.puts
    end
    io.puts "CCLI Number: -"
    io.puts artist
    io.puts info
    io.puts "For use within terms of license."
    io.puts "All rights Reserved.  www.ccli.com"
    io.puts "CCLI License No. -"
    io.string
  end

  def string_from_puts
    alias old_puts puts
    old_puts = method(:puts)
    define_singleton_method :puts, &string_io.method(:puts)
    yield
  ensure
    undef_method :puts
    string_io.string
  end

  def parse_header_line line
    line.strip!
    (@title = line and return) unless @title  # "The first line is taken as the title."
    case line
    when /^\.a(.*)/
      @artist = $1.strip
    when /^\.i(.*)/
      @info = $1.strip
    when /^\.s(.*)/
      @sequence = $1.strip
    when /^\.k(.*)/
      @key = $1.strip
    when /^\.b(.*)/
      @background = $1.strip
    # do we also have some with .c ?
    when /^\s*$/
      @header_complete = true  # blank line ends header
    else
      if @artist
        @header_complete = true
      else
        @artist = line
      end
    end
  end

  def parse_body_line line, i
    case line
    when /^\.([0*])\s*$/
      slides << Slide.new("Chorus")
    when /^\.([9\/])\s*$/
      slides << Slide.new("Bridge")
    when /^\.([1-8])\s*$/
      slides << Slide.new($1)
    when /^\.\s*$/
      slides.last.body << " \n"
    when /^\./  # e.g. .- .# .b
      nil
    when /^\s*$/
      slides << Slide.new
    else
      slides << Slide.new if slides.empty?
      slides.last.body << line
    end
  end

  class Slide
    attr_accessor :number, :body

    def initialize number = "-"
      @number = number
      @body = ""
    end

    def empty?
      @body.to_s.strip.empty?
    end
  end
end

class ProPresenter5Song
  attr_reader :xml

  def initialize(string)
    @xml = Nokogiri(string.encode('UTF-8'), nil, 'UTF-8')
    @xml.encoding = 'ISO-8859-1'
  end

  def doc
    xml.css('RVPresentationDocument')[0]
  end

  def slide_groups
    doc.css('RVDisplaySlide') #RVDisplaySlide
  end

  def update_from presenter_song
    unless presenter_song.kind_of?(PresenterSong)
      raise ArgumentError, "cannot convert #{presenter_song.inspect}:#{presenter_song.class} to PresenterSong"
    end
    doc['CCLISongTitle'] = presenter_song.title
    doc['artist'] = presenter_song.artist
    doc['author'] = presenter_song.artist
    doc['CCLICopyRightInfo'] = presenter_song.info  # where does this go in the interface?
    doc['notes'] = [("Key: #{presenter_song.key}" if presenter_song.key),
      ("Sequence: #{presenter_song.sequence}" if presenter_song.sequence)].compact.join("\n")
    slide_groups.zip(presenter_song.slides).each do |slide_group, slide|
      slide_group["name"] = slide.number =~ /^\d+$/ ? "Verse #{slide.number}" : slide.number
    end
  end

  def to_s
    xml.to_s.encode('ISO-8859-1')
  end
end

if __FILE__ == $0
  require 'fileutils'
  require 'pathname'

  case ARGV[0]
  when "-1"
    OUTPUT_DIR = "plain_text"
    FileUtils.mkdir_p OUTPUT_DIR
    Dir['*.txt'].each do |filename|
      song = PresenterSong.new(File.read(filename))
      File.open "#{OUTPUT_DIR}/#{filename}", "w" do |f_out|
        f_out.puts song.to_s(:plain_text)
      end
    end
  when "-2"
    PRESENTER_TEXT_DIR = "."
    PROPRESENTER_DIR = 'propresenter_xml'
    OUTPUT_DIR = "modified_xml"
    FileUtils.mkdir_p OUTPUT_DIR
    Dir['*.txt'].each do |filename|
      pro5_name = filename.sub(/txt/i, 'pro5')
      song = PresenterSong.new File.read(filename)
      pro5 = ProPresenter5Song.new File.read("#{PROPRESENTER_DIR}/#{pro5_name}")
      # p [song.slides.size, pro5.slide_groups.size, filename]
      binding.pry if song.slides.size != pro5.slide_groups.size
      pro5.update_from song
      File.open "#{OUTPUT_DIR}/#{pro5_name}", "w" do |f|
        f.puts pro5.to_s
      end
    end
  else
    STDERR.puts <<-END
usage: #{$0} -1  # OR  #{$0} -2"
OPTIONS:
    -1    Strip down Presenter .txt files from current directory into
          plain text files in the ./plain_text directory.
    -2    Supplement ProPresenter5 .pro5 files in ./propresenter_xml directory
          with metadata from Presenter .txt files from current directory and
          store output into the ./modified_xml directory.
    END
  end
end
