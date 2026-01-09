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

  def calc_payment(profile, date)
    配偶者控除 = profile.include?('spouse')
    扶養控除 = self.class.扶養控除対象者の数(profile['family'], Date.new(date.year, 12, 31))
    {}.tap do |h|
      select_code(profile, '1').each { |k, v| h[k] = v }
      h['201'] = @insurance.health_insurance_salary(
        insurance_rank(profile),
        介護保険?(profile['birth_date'])
      )
      h['202'] = @insurance.pension_salary(pension_rank(profile))
      tax_base = self.class.sum_code(h, '1', income_tax_exception) - h['201'] - h['202']
      h['203'] = JpNationalTax::IncomeTax.calc_kouran(tax_base, Date.today, 配偶者控除, 扶養控除)
      h['211'] = resident_tax(profile)
      select_code(profile, '3').each { |k, v| h[k] = v }
      select_code(profile, '4').each { |k, v| h[k] = v }
      h.merge!(amount_by_code(h))
      h['id'] = profile.fetch('id')
    end
  end

  def self.year_total(profile, payment, date)
    raise '年末調整の対象となりません' if payment['1'] == 0

    給与等の金額 = JpNationalTax::IncomeTax.year_salary_taxable(payment['1'], date)
    payment.tap do |p|
      p['901'] = 給与等の金額
      p['911'] = JpNationalTax::IncomeTax.basic_deduction(給与等の金額, date)
      p['916'] = 配偶者控除の金額(p['1'], profile['spouse'], date)
      p['917'] = 配偶者特別控除の金額(p['1'], profile['spouse'], date)
      p['918'] = 扶養控除の金額(profile['family'], date)
      p['912'] = ['201', '202', '204', '205'].map{ |cd| p[cd] }.compact.sum
      課税給与所得金額 = 給与等の金額 - ['911', '912', '916', '917', '918'].map{ |cd| p[cd] }.compact.sum
      p['941'] = (課税給与所得金額 / 1000).floor * 1000
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

  def self.配偶者控除の金額(income, spouse, date)
    puts spouse
    return nil if spouse.nil?

    puts spouse
    spouse_salary = JpNationalTax::IncomeTax.year_salary_taxable(spouse['income'][date.year.to_s] || 0, date)
    return 0 if spouse_salary > 480_000

    salary = JpNationalTax::IncomeTax.year_salary_taxable(income || 0, date)
    birth_date = spouse['birth_date'] || date
    if salary <= 9_000_000
      birth_date <= date.prev_year(70) ? 480_000 : 380_000
    elsif salary <= 9_500_000
      birth_date <= date.prev_year(70) ? 320_000 : 260_000
    elsif salary <= 10_000_000
      birth_date <= date.prev_year(70) ? 160_000 : 130_000
    else
      0
    end
  end

  def self.配偶者特別控除の金額(income, spouse, date)
    return nil if spouse.nil?

    salary = JpNationalTax::IncomeTax.year_salary_taxable(income || 0, date)
    return 0 if salary > 10_000_000

    spouse_salary = JpNationalTax::IncomeTax.year_salary_taxable(spouse['income'][date.year.to_s] || 0, date)
    return 0 if spouse_salary <= 480_000
    return 0 if spouse_salary > 1_330_000

    if salary <= 9_000_000
      return 380_000 if spouse_salary <= 950_000
      return 360_000 if spouse_salary <= 1_000_000
      return 310_000 if spouse_salary <= 1_050_000
      return 260_000 if spouse_salary <= 1_100_000
      return 210_000 if spouse_salary <= 1_150_000
      return 160_000 if spouse_salary <= 1_200_000
      return 110_000 if spouse_salary <= 1_250_000
      return 60_000 if spouse_salary <= 1_300_000
      return 30_000
    elsif salary <= 9_500_000
      return 260_000 if spouse_salary <= 950_000
      return 240_000 if spouse_salary <= 1_000_000
      return 210_000 if spouse_salary <= 1_050_000
      return 180_000 if spouse_salary <= 1_100_000
      return 140_000 if spouse_salary <= 1_150_000
      return 110_000 if spouse_salary <= 1_200_000
      return 80_000 if spouse_salary <= 1_250_000
      return 40_000 if spouse_salary <= 1_300_000
      return 20_000
    else
      return 130_000 if spouse_salary <= 950_000
      return 120_000 if spouse_salary <= 1_000_000
      return 110_000 if spouse_salary <= 1_050_000
      return 90_000 if spouse_salary <= 1_100_000
      return 70_000 if spouse_salary <= 1_150_000
      return 60_000 if spouse_salary <= 1_200_000
      return 40_000 if spouse_salary <= 1_250_000
      return 20_000 if spouse_salary <= 1_300_000
      return 10_000
    end
  end

  def self.扶養控除の金額(family, date)
    return if family.nil?

    family.map { |person| 各家族の扶養控除の額(person, date) }.sum
  end

  def self.各家族の扶養控除の額(person, date)
    birth_date = person['birth_date']
    return 0 if birth_date.nil?

    if birth_date > date.prev_year(16)
      0
    elsif birth_date <= date.prev_year(70)
      person['live_with'] ? 580_000 : 480_000 # 老人扶養親族
    elsif birth_date <= date.prev_year(19) and birth_date > date.prev_year(23)
      630_000 # 特定扶養親族
    else
      380_000
    end
  end

  def self.扶養控除対象者の数(family, date)
    family.map { |person| 各家族の扶養控除の額(person, date) > 0 ? 1 : 0 }.sum
  end

  private

  # 満40歳に達したときより徴収が始まり、満65歳に達したときより徴収されなくなる
  #
  def 介護保険?(birth_date)
    return nil if birth_date.nil?

    due_init = birth_date.next_year(40).prev_day
    return false if @date.year < due_init.year
    return false if @date.year == due_init.year && @date.month < due_init.month

    due_last = birth_date.next_year(65).prev_day
    return false if @date.year > due_last.year
    return false if @date.year == due_last.year && @date.month >= due_last.month

    true
  end

  def insurance_rank(dat)
    dat.dig('insurance', 'rank')
  end

  def income_tax_exception
    %w[116 118 119 11A 11B]
  end

  def pension_rank(dat)
    dat.dig('pension', 'rank')
  end

  def resident_tax(dat)
    attr = @date.month == 6 ? 'extra' : 'ordinal'
    dat.dig('resident', attr)
  end
end
