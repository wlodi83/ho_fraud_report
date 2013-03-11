require 'dbi'
require 'odbc_utf8'

class Exasol

  def self.execute_query(script)
    begin
      config = YAML.load_file("config/config.yaml")
      dbh = DBI.connect('DBI:ODBC:EXA', config["login"], config["password"])
      result = []
      sth = dbh.execute(script)
      while row = sth.fetch_array do
        result << row
      end
      col_names = sth.column_names
      sth.finish
      return result, col_names
    rescue Exception => e
      print "An error occured with script"
    ensure
      dbh.disconnect if dbh
    end
  end

end
