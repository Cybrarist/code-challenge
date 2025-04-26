# frozen_string_literal: true

require 'spec_helper'
require 'json'
require_relative '../lib/crawler'

RSpec.describe Crawler do
  before(:all) do
    @crawler = Crawler.new('../files/van-gogh-paintings.html', 'output.json', 'Cz5hV', 'iELo6', false)
    puts('running once')
  end

  it 'should file parsed and title can be seen' do
    @title_string = @crawler.parsed_html_file.css('title').text
    expect(@title_string).to eq('Van Gogh paintings - Google Search')
  end

  # 5 was chosen as I tested the images that show in the beginning, and most of the time
  # they were more than 5.
  # of course I can change the number to be greater than 1 since the first image is not
  # useful for us
  it 'should get the base64 images' do
    @crawler.parse_images_base64_and_ids
    expect(@crawler.key_image_hash.length).to be >= 5
  end

  it 'should get the divs that contains the artworks' do
    @crawler.parse_divs_that_contains_artworks
    expect(@crawler.final_results['artworks'].length).to be >= 5
  end

  it 'should artworks value should be the same for all values' do
    expect(@crawler.final_results).to have_key('artworks')

    @expected_artworks = JSON.parse(File.read('../files/expected-array.json'))

    # make sure the artwork key exists
    expect(@crawler.final_results['artworks'].length).to be

    # check if the length is equal, if not, then there are missing values or more than expected (which we might need to double check).
    expect(@crawler.final_results['artworks'].length).to eq(@expected_artworks['artworks'].length)

    # assuming the expected array and result array are not ordered the same
    # as if Google might switch the result order.
    # I will be identifying using the name of the artwork
    @crawler.final_results['artworks'].each do |artwork|
      @index_found = -1

      @expected_artworks['artworks'].each_with_index do |expected_artwork, index|
        if artwork['name'] == expected_artwork['name']
          @index_found = index
          break
        end
      end

      expect(artwork['name']).to eq(@expected_artworks['artworks'][@index_found]['name'])
      expect(artwork['image']).to eq(@expected_artworks['artworks'][@index_found]['image'])
      expect(artwork['link']).to eq(@expected_artworks['artworks'][@index_found]['link'])

      next unless artwork.key?('extensions')

      expect(artwork['extensions'].length).to eq(@expected_artworks['artworks'][@index_found]['extensions'].length)
      expect(artwork['extensions']).to eq(@expected_artworks['artworks'][@index_found]['extensions'])
    end
  end


  # I can check if values are the same, but highly doubt it will be different after checking length
  # since the original function just print out the results
  it 'should populate output.json file and results are in equal length' do
    # make sure the file doesn't exist, so we don't get previous data by mistake
    expect(File.exist?('output.json')).to be false
    @crawler.output_result_to_json
    expect(File.exist?('output.json')).to be true

    @output_json_file = JSON.parse(File.read('output.json'))

    expect(@output_json_file['artworks'].length).to be @crawler.final_results['artworks'].length

    File.delete('output.json')
  end
end
