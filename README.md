<h1>Instructions:</h1>
<h3>Install Gems:</h3>
<p>gem install spreadsheet</p>
<p>gem install yajl-ruby</p>
<p>change file name from config.yml.sample to config.yml in folder config/ and fill it with correct HasOffers API and EXASOL credentials</p>
<h3>How to run report:</h3>
<p>
Please provide one of following command:

  Usage:
    ruby generate_report.rb weekend
    ruby generate_report.rb today
    ruby generate_report.rb yesterday
</p>
<h3>Result:</h3>
<p>Generated report you can find in file: ho_fraud_report.xls</p>
