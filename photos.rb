#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'exif'
require 'mongo'
require 'thread'

bucket = 'http://s3.amazonaws.com/waldo-recruiting'
thread_pool_size = 20
mongo_host = '127.0.0.1:27017'
Mongo::Logger.logger.level = ::Logger::INFO

def parse_bucket(bucket)
  xml_doc = Nokogiri::Slop(open(bucket))

  # Breaking the law of demeter
  contents = xml_doc.html.body.listbucketresult.contents
  photos = []
  contents.each do |photo_item|
    photos << photo_item.key.text
  end
  photos
end

def download_photo(bucket, photo_name)
  file = Tempfile.new(photo_name)
  file.binmode

  photo_uri = URI(bucket + '/' + photo_name)
  resp = Net::HTTP.get_response(photo_uri)
  file.write(resp.body)
  file.flush
  file.path
end

def parse_exif(photo_file)
  Exif::Data.new(photo_file)[:exif]
rescue
  puts "Unable to parse EXIF data for file #{photo_file}"
end

def load_db(mongo_host)
  client = Mongo::Client.new([mongo_host], database: 'waldo')
  collection = client[:photos]
  collection.indexes.create_one({ name: 1 }, unique: true)
  collection
end

# Queries Mongodb to see if the photo name exists
def photo_missing(db, photo_name)
  db.find(name: photo_name).limit(1).count == 0
end

def write_db(db, photo_name, exif)
  doc = exif.clone
  doc[:name] = photo_name
  db.insert_one(doc)
  puts "#{photo_name} has been inserted"
end

def process_photo(database, bucket, photo_name)
  if photo_missing(database, photo_name)
    photo_file = download_photo(bucket, photo_name)
    exif = parse_exif(photo_file)
    write_db(database, photo_name, exif) if exif
  else
    puts "#{photo_name} has already been inserted"
  end
rescue StandardError => exception
  puts "Error in processing photo #{photo_name}" + exception.backtrace.to_s
end

database = load_db(mongo_host)
photo_names = parse_bucket(bucket)

work = Queue.new
photo_names.each do |photo_name|
  work.push photo_name
end

workers = (0...thread_pool_size).map do
  Thread.new do
    while photo_name = work.pop(true)
      process_photo(database, bucket, photo_name)
      break if work.empty?
    end
  end
end
workers.map(&:join)
