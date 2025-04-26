# frozen_string_literal: true

require 'nokogiri'
require 'json'

class Crawler
  GOOGLE_BASE_SEARCH_URL = 'https://www.google.com'
  PARENT_ARTWORK_DIV_CLASS = 'Cz5hV'
  PAGE_ARTWORK_CLASS = 'iELo6'

  # make the following variables publicly accessible only if we're using RSpec
  if defined?(RSpec)
    puts 'making attributes public when running tests'
    attr_reader :parsed_html_file
    attr_reader :key_image_hash
    attr_reader :final_results
    attr_reader :output_json_file_path
    attr_reader :artwork_class
  end

  def initialize(
    input_html_file,
    output_json_file_path,
    parent_artwork_class = PARENT_ARTWORK_DIV_CLASS,
    page_artwork_class = PAGE_ARTWORK_CLASS,
    run_crawling_process = true
  )
    # make sure the passed value is string
    raise TypeError, 'File name should be passed as string' unless input_html_file.is_a?(String)
    # make sure the file exists
    raise IOError, "File doesn't exists: #{input_html_file}" unless File.exist?(input_html_file)

    # initialize required information
    @output_json_file_path = output_json_file_path
    @parent_artwork_class = parent_artwork_class
    @page_artwork_class = page_artwork_class
    @key_image_hash = {}
    @final_results = {}
    @final_results['artworks'] = []
    @parsed_html_file = File.open(input_html_file) { |f| Nokogiri::HTML(f) }

    # I made the class to be a single run when initializing the class.
    # but I don't want to run everything when I am testing
    start_crawling_process if run_crawling_process
  end

  def start_crawling_process
    parse_images_base64_and_ids
    parse_divs_that_contains_artworks
    output_result_to_json
  end

  # get all base64 images from the script tags, then remove / replace the required characters.
  def parse_images_base64_and_ids
    @parsed_html_file.xpath('//script[@nonce and count(@*) = 1]').each do |script|
      match = script.content.scan(%r{(data:image/jpeg;base64.*.var ii.*?)\];}m)
      next unless match.length.positive?

      image_and_key = match[0].to_s.split(';var')
      # remove all the extra stuff not needed from the key.
      key = image_and_key[1].gsub(/["'\]\[=]|ii|\s+/, '')

      image = image_and_key[0].gsub(/[\['"]/, '').gsub(/\\\\x3d|\\x3d/, '=')

      @key_image_hash[key] = image
    end
  end

  # get the divs that contains the artwork class and replace the ones we ones 
  # that needed with the parsed base64 value
  # Along with appending the value directly to @final_results
  def parse_divs_that_contains_artworks
    # try to get the artworks with the class specified directly
    divs_with_artworks = @parsed_html_file.css("div.#{@page_artwork_class}")

    # If for any reason the direct artwork class has changed, then try to get the parent class
    # and assuming the same structure. We will get the direct divs
    if divs_with_artworks.empty?
      divs_with_artworks = @parsed_html_file.css("div.#{@parent_artwork_class}").css('>div')
      # simulating log
      puts "couldn't get the artworks with the direct class, trying with the parent class"
    end

    divs_with_artworks.each do |div|
      link_tag = div.css('a')
      img_tag = link_tag.css('img')
      artwork_name_div = link_tag.css('div>div:first-child')
      artwork_year_div = link_tag.css('div>div:not(:first-child)')

      # I can create a small class that contains this information, then I can convert the data to different
      # structures. but it's not required, so the below should be enough

      @final_results['artworks'] << {
        'name' => artwork_name_div.text,
        **(artwork_year_div.text.length.positive? ? { 'extensions'=> [artwork_year_div.text] } : {}),
        'link' => GOOGLE_BASE_SEARCH_URL + link_tag.attribute('href').value,
        'image' => img_tag.attribute('data-src') ? img_tag.attribute('data-src').value : @key_image_hash[img_tag.attribute('id').value]
      }
    end
  end

  # the expected result file has an extra line that I didn't add as I am not sure
  # if it was intentional, or it's appended by the OS.
  # if it was intentional, it would make testing the results easier as I would compare
  # the hashes of expected and actual files to make sure they are equal.
  def output_result_to_json
    File.open(@output_json_file_path, 'w') do |f|
      f.write(JSON.pretty_generate(@final_results))
    end
  end
end
