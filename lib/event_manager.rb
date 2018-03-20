require "csv"
require "google/apis/civicinfo_v2"
require "erb"
require "date"


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_numbers(phone_number)
  phone_number = phone_number.to_s.gsub(/[^0-9]/, "")

  if phone_number.length < 10 || phone_number.length >= 11
  	phone_number = "1234567890"
  elsif phone_number.length == 11 && phone_number[0] == 1
  	phone_number = phone_number[1..10]
  else
  	phone_number
  end

end

def legislators_by_zipcode(zip)  
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'your api key'

  begin
    civic_info.representative_info_by_address(
  	  address: zip,
  	  levels: 'country',
  	  roles: ['legislatorUpperBody', 'legislatorLowerBody']
  	).officials
  rescue
  	"You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letters(id, form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_registration_date(registration)
  registration_time = registration.split(" ")[1].to_s.rjust(4, "0")
  registration_date = registration.split(" ")[0].to_s
  registration_date = registration_date.split("/")
  month_day = registration_date[1].rjust(2, "0")
  month = registration_date[0].rjust(2, "0")
  year = registration_date[2].rjust(4, "20")
  registration_date = "#{month_day}-#{month}-#{year}"
  registration_date = DateTime.strptime("#{registration_date} #{registration_time}", '%d-%m-%Y %H:%M')
end

def populate_hour_counter(my_hash)
  24.times do |index|
    my_hash_index = index.to_s.rjust(2, "0")
    my_hash[my_hash_index] = 0
  end
  my_hash
end

def populate_weekday_counter(my_hash)
  my_hash["Monday"] = 0
  my_hash["Tuesday"] = 0
  my_hash["Wednesday"] = 0
  my_hash["Thursday"] = 0
  my_hash["Friday"] = 0
  my_hash["Saturday"] = 0
  my_hash["Sunday"] = 0

  my_hash
end

puts "EventManager initialized."

contents = CSV.open "event_attendees.csv", headers: true, header_converters: :symbol

template_letter = File.read "../form_letter.erb"
erb_template = ERB.new template_letter

registration_hour_counter = populate_hour_counter(Hash.new)
registration_weekday_counter = populate_weekday_counter(Hash.new)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_numbers(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)
  
  registration_date = clean_registration_date(row[:regdate])
  
  registration_hour = registration_date.hour.to_s.rjust(2, "0")
  registration_hour_counter[registration_hour] += 1
  registration_weekday = registration_date.strftime('%A')
  registration_weekday_counter[registration_weekday] += 1
  
  form_letter = erb_template.result(binding)

  save_thank_you_letters(id, form_letter)
end

puts "The best hour to target with ads is #{registration_hour_counter.max_by{|k,v| v}[0]}:00"
puts "The best day of the week to target with ads is #{registration_weekday_counter.max_by{|k,v| v}[0]}"
