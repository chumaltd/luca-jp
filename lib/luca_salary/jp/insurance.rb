require 'bigdecimal'
require 'date'
require 'json'
require 'pathname'

class InsuranceJP
  attr_reader :table

  # load config
  def initialize(dir_path, area=nil, date=nil)
    @pjdir = Pathname(dir_path) + 'dict'
    @area = area
    @date = date
    @table = load_table
  end

  def load_table
    file_name = @pjdir + select_active_filename
    JSON.parse(File.read(file_name.to_s))
  end

  def health_insurance_salary(rank)
    round6(select_health_insurance(rank).dig('insurance_elder_salary'))
  end

  def pension_salary(rank)
    round6(select_pension(rank).dig('pension_salary'))
  end

  def select_health_insurance(rank)
    @table['fee'].filter{|h| h['rank'] == rank}.first
  end

  def select_pension(rank)
    @table['fee'].filter{|h| h['pension_rank'] == rank}.first
  end

  private

  def round6(num)
    BigDecimal(num).round(0, BigDecimal::ROUND_HALF_DOWN).to_i
  end

  def select_active_filename
    list_json
             .filter { |tbl| tbl[0] <= @date }
             .max { |a, b| a[0] <=> b[0] }
             .last
  end

  def list_json
    table_list = [].tap do |a|
      open_tables do |f, name|
        data = JSON.parse(f.read)
        next if @area && data['area'] != @area

        a << [Date.parse(data['effective_date']), name]
      end
    end
  end

  # TODO: Limit only to pension tables.
  def open_tables
    Dir.chdir(@pjdir.to_s) do
      Dir.glob("*.json").each do |file_name|
        File.open(file_name, 'r') {|f| yield(f, file_name)}
      end
    end
  end
end
