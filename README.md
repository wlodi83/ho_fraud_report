<h1>Instructions:</h1>
<h3>Install Gems:</h3>
<p>gem install spreadsheet</p>
<p>gem install yajl-ruby</p>
<p>change file name from config.yml.sample to config.yml in folder config/ and fill it with correct HasOffers API and EXASOL credentials</p>
<h3>How to run report:</h3>
<p>Please provide one of following command:</p>
<p>Usage:</p>
<ul>
<li>ruby generate_report.rb weekend</li>
<li>ruby generate_report.rb today</li>
<li>ruby generate_report.rb yesterday</li>
</ul>
<h3>Result:</h3>
<p>You should find generated in file: ho_fraud_report.xls</p>
