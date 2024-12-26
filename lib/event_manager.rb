require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def peak_registration_hours(contents)
  hours = Hash.new(0)

  contents.each do |row|
    reg_date = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')
    hour = reg_date.hour
    hours[hour] += 1
  end

  peak_hours = hours.select { |hour, count| count == hours.values.max }
  peak_hours.keys
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def peak_registration_days(contents)
  days = Hash.new(0)

  contents.each do |row|
    reg_date = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')
    day_of_week = reg_date.strftime('%A')
    days[day_of_week] += 1
  end

  peak_days = days.select { |day, count| count == days.values.max }
  peak_days.keys
end

def clean_phone_number(phone_number)
  phone_number = phone_number.gsub(/\D/, '') # Remove non-digit characters

  if phone_number.length < 10 || phone_number.length > 11
    '0000000000' # Bad number
  elsif phone_number.length == 10
    phone_number # Good number
  elsif phone_number.length == 11
    if phone_number[0] == '1'
      phone_number[1..10] # Trim the leading 1
    else
      '0000000000' # Bad number
    end
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

  put "#{name} #{zipcode} #{phone_number}"
end

peak_hours = peak_registration_hours(contents)
peak_days = peak_registration_days(contents)
puts "Peak registration hours: #{peak_hours.join(', ')}"
puts "Peak registration days: #{peak_days.join(', ')}"
