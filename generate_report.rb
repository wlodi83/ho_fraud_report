require File.join(File.dirname(__FILE__), 'lib/requester')
require File.join(File.dirname(__FILE__), 'lib/exasol')
require 'date'
require 'time'
require 'spreadsheet'
require 'yaml'
require 'yajl'

#load config file
config = YAML.load_file("config/config.yaml")

#Create result file
result = Spreadsheet::Workbook.new
sheet1 = result.create_worksheet
sheet1.name = 'HasOffers Fraud Report'
sheet1.row(0).concat %w{Offer_ID Offer_Name Advertiser Approved Rejected Perc_of_Rejected_Conversions Potential_Damage Offer_Whitelisted? Offer_Protocol? Allow_Multiple_Conversions? Perc_Of_Rejected_Conversions_From_Certain_Application_Threshold_20%}

row_counter = 1

ho_request = {
  "NetworkId" => config["network_id"],
  "NetworkToken" => config["network_token"],
  "Target" => "Report",
  "Method" => "getConversions",
  "fields[0]" => "Offer.id",
  "fields[1]" => "Offer.name",
  "fields[2]" => "Stat.count_approved",
  "fields[3]" => "Stat.net_payout",
  "fields[4]" => "Stat.count_rejected",
  "fields[5]" => "Stat.rejected_rate",
  "groups[0]" => "Offer.name",
  "filters[Stat.date][conditional]" => "BETWEEN",
  "sort[Stat.count_rejected]" => "desc",
  "limit" => "50",
  "page" => "1",
  "totals" => "1",
  "hour_offset" => "0"
}

case ARGV[0]
when "yesterday" 
  date = (Time.now - 86400).strftime("%Y-%m-%d")
  response = Requester.make_request(
    config["url"],
    ho_request.merge(
      {
        "filters[Stat.date][values][0]" => date,
        "filters[Stat.date][values][1]" => date
      }
    ),
    :get
  )
when "today"
  date = Time.now.strftime("%Y-%m-%d")
  response = Requester.make_request(
    config["url"],
    ho_request.merge(
      {
        "filters[Stat.date][values][0]" => date,
        "filters[Stat.date][values][1]" => date
      }
    ),
    :get
  )
when "weekend"
  start = Time.now.strftime("%Y-%m-%d")
  end_time = (Time.now - 259200).strftime("%Y-%m-%d")
  response = Requester.make_request(
    config["url"],
    ho_request.merge(
      {
        "filters[Stat.date][values][0]" => end_time,
        "filters[Stat.date][values][1]" => start
      }
    ),
    :get
  )
else
  STDOUT.puts <<-EOF
  Please provide one of following command:

  Usage:
    ruby generate_report.rb weekend
    ruby generate_report.rb today
    ruby generate_report.rb yesterday
  EOF
end

#Parse JSON data
json = StringIO.new(response)
parser = Yajl::Parser.new
hash = parser.parse(json)

hash["response"]["data"]["data"].each do |offer|
  
  offer_info = Requester.make_request(
    config["url"],
    {
    "NetworkId" => config["network_id"],
    "NetworkToken" => config["network_token"],
    "Target" => "Offer",
    "Method" => "findById",
    "id" => offer["Offer"]["id"]
    },
    :get
  )

  json = StringIO.new(offer_info)
  parser = Yajl::Parser.new
  offer_hash = parser.parse(json)

  oh = offer_hash["response"]["data"]["Offer"]

  advertiser_info = Requester.make_request(
    config["url"],
    {
    "NetworkId" => config["network_id"],
    "NetworkToken" => config["network_token"],
    "Target" => "Advertiser",
    "Method" => "findById",
    "id" => oh["advertiser_id"]
    },
    :get
  )

  json = StringIO.new(advertiser_info)
  parser = Yajl::Parser.new
  advertiser_hash = parser.parse(json)

  ah = advertiser_hash["response"]["data"]["Advertiser"]

  status_info = Requester.make_request(
    config["url"],
    {
    "NetworkId" => config["network_id"],
    "NetworkToken" => config["network_token"],
    "Target" => "Report",
    "Method" => "getConversions",
    "fields[0]" => "Stat.affiliate_info4",
    "filters[Stat.status][conditional]" => "EQUAL_TO",
    "filters[Stat.status][values][0]" => "rejected",
    "filters[Offer.id][conditional]" => "EQUAL_TO",
    "filters[Offer.id][values][0]" => offer["Offer"]["id"],
    "filters[Stat.date][conditional]" => "BETWEEN",
    "filters[Stat.date][values][0]" => date,
    "filters[Stat.date][values][1]" => date,
    "limit" => "10000",
    "page" => "1",
    "totals" => "1"
    },
    :get
  )

  json = StringIO.new(status_info)
  parser = Yajl::Parser.new
  status_hash = parser.parse(json)

  appid_code = []

  status_hash["response"]["data"]["data"].each do |item|
    application_id = item["Stat"]["affiliate_info4"]
    appid_code << application_id
  end

  grouped = Hash.new

  appid_code.group_by {|x| x}.each{|x,y| grouped["#{x}"] = "#{((y.size*100)/offer["Stat"]["count_rejected"].to_f).round(2)}"}
  apps = grouped.sort_by{ |h| h[1].to_i }.reverse!

  puts apps

  status_res = String.new

  case oh["protocol"]
  when "http_img"
    protocol = "Image Pixel"
  when "https_img"
    protocol = "Secure Image Pixel"
  when "server"
    protocol = "Server to Server"
  when "http"
    protocol = "iFrame Pixel"
  when "https"
    protocol = "Secure iFrame Pixeli"
  end

  potential_damage = (oh["default_payout"].to_f * offer["Stat"]["count_rejected"].to_f).round(2)
  if oh["currency"].nil? or oh["currency"].empty? or oh["currency"] == ""
    currency = "EUR"
  else
    currency = oh["currency"]
  end

  puts oh["currency"]

  damage = potential_damage.to_s + ' ' + currency
  if damage.to_f > 20
    apps.each do |k, v|
      if v.to_f > 20 and !k.empty?
        app_query = "select app.name from cms.applications as app where app.id = '#{k}'"

        app_result = Exasol.execute_query(app_query)[0][0]

        if app_result.nil?
          status_res << "#{v}% from application #{k}, "
        else
          status_res << "#{v}% from application #{app_result}, "
        end
      end
    end
    if !status_res.empty?
      sheet1.row(row_counter).push offer["Offer"]["id"], offer["Offer"]["name"], ah["company"], offer["Stat"]["count_approved"], offer["Stat"]["count_rejected"], (offer["Stat"]["rejected_rate"].to_f).round(2), damage, oh["enable_offer_whitelist"] == "0" ? "No" : "Yes", protocol, oh["allow_multiple_conversions"] == "0" ? "No" : "Yes", status_res.chop.chop
      row_counter += 1
    end
  end
end

result.write 'ho_fraud_report.xls'
