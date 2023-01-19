require 'luca_salary/jp/version'
require 'date'
require 'luca_salary'
require 'luca_salary/jp/insurance'
require 'jp_national_tax'

class LucaSalary::Jp < LucaSalary::Base
  def initialize(dir_path, config = nil, date = nil)
    @pjdir = dir_path
    @date = date
    @insurance = InsuranceJP.new(@pjdir, config.dig('jp', 'area'), date)
  end

  # need for local dictionary loading
  def self.country_path
    __dir__
  end

  def calc_payment(profile)
    {}.tap do |h|
      select_code(profile, '1').each { |k, v| h[k] = v }
      h['201'] = @insurance.health_insurance_salary(insurance_rank(profile))
      h['202'] = @insurance.pension_salary(pension_rank(profile))
      tax_base = self.class.sum_code(h, '1', income_tax_exception) - h['201'] - h['202']
      h['203'] = JpNationalTax::IncomeTax.calc_kouran(tax_base, Date.today, true)
      h['211'] = resident_tax(profile)
      select_code(profile, '3').each { |k, v| h[k] = v }
      select_code(profile, '4').each { |k, v| h[k] = v }
      h.merge!(amount_by_code(h))
      h['id'] = profile.dig('id')
    end
  end

  def self.year_total(payment, date)
    payment.tap do |p|
      p['911'] = JpNationalTax::IncomeTax.basic_deduction(p['1'], date)
      p['916'] = partner_deduction(p['1'])
      p['912'] = ['201', '202', '204', '205'].map{ |cd| p[cd] }.compact.sum
      p['901'] = JpNationalTax::IncomeTax.year_salary_taxable(p['1'], date)
      p['941'] = p['901'] - p['911'] - p['912'] - p['916']
      p['961'] = JpNationalTax::IncomeTax.year_tax(p['941'], date)
      diff = p['961'] - p['203']
      if diff.positive?
        p['3A1'] = diff
        p['4A1'] = BigDecimal('0')
      else
        p['4A1'] = diff * -1
        p['3A1'] = BigDecimal('0')
      end
      p.delete '3'
      p.delete '4'
      p['3'] = sum_code(p, '3')
      p['4'] = sum_code(p, '4')
    end
  end

  def self.partner_deduction(income)
    if income <= 9_000_000
      380_000
    elsif income <= 9_500_000
      260_000
    elsif income <= 10_000_000
      130_000
    else
      0
    end
  end

  def income_tax_exception
    %w[116 118 119 11A 11B]
  end

  def insurance_rank(dat)
    dat.dig('insurance', 'rank')
  end

  def pension_rank(dat)
    dat.dig('pension', 'rank')
  end

  def resident_tax(dat)
    attr = @date.month == 6 ? 'extra' : 'ordinal'
    dat.dig('resident', attr)
  end
end
