# frozen_string_literal: true
require 'luca_salary'
require 'luca_support/config'
require 'csv'
require 'open3'

module LucaSalary
  class JpPayreport < LucaSalary::Base

      def self.export(year)
        if !system("uconv --version > /dev/null")
          exit 1 # 半角カナ必須
        end

        slips = LucaSalary::Total.new(year).slips
        company = set_company(year.to_i)
        CSV.generate() do |csv|
          slips.each do |s|
            csv << 給与支払報告明細行(LucaSupport::Code.readable(s), company, year.to_i)
          end
        end
      end

      # TODO: extract effective field
      def self.set_company(year)
        {}.tap do |h|
          h['name'] = CONFIG.dig('company', 'name')
          h['address'] = CONFIG.dig('company', 'address')
          h['address2'] = CONFIG.dig('company', 'address2')
          h['tel'] = CONFIG.dig('company', 'tel')
          h['tax_id'] = CONFIG.dig('company', 'tax_id')

          raise "会社名、住所の設定は必須" if h['name'].nil? or h['address'].nil?
        end
      end
  end
end

private

def 給与支払報告明細行(slip, company, year)
  [
    315, # 法定資料の種類
    提出義務者(company),
    0, # 提出区分（新規0, 追加1, 訂正2, 取消3）
    和暦(Date.new(year, 12, -1))[1], # 年分
    支払を受ける者(slip['profile']),
    支払(slip, year),
    支払を受ける者の詳細(slip['profile'], year),
    company['tax_id'], # 法人番号
    支払を受ける者の扶養情報(slip['profile'], year),
    slip['911'], # 基礎控除の額
    nil, # 所得金額調整控除額 TODO: 未実装 措法41の3の3
    nil, # ひとり親
    提出先判定(slip), # 必須：作成区分（国税のみ0, 地方のみ1, 両方2）
  ].flatten
end

def 提出義務者(company)
  [
    nil,  # 整理番号1
    nil,  # 本支店等区分番号
    ['address', 'address2'].map { |attr| company[attr] }
      .compact.join('　'), # 必須：住所又は所在地
    company['name'], # 必須：氏名又は名称
    company['tel'],  # 電話番号
    nil,  # 整理番号2
    nil,  # 提出者の住所（省略する）
    nil,  # 提出者の氏名（省略する）
  ]
end

def 支払を受ける者(profile)
  [
    ['address', 'address2'].map { |attr| profile[attr] }
      .compact.join('　'), # 必須：住所又は居所
    nil, # 国外住所表示（国内は"0"、国外は"1"）
    profile['name'], # 必須：氏名
    nil, # 役職名
  ]
end

def 支払(slip, year)
  配偶者控除等 = [slip['916'], slip['917']].compact.sum
  [
    '給料', # 種別
    slip['1'], # 支払金額
    nil, # 未払金額
    slip['901'], # 給与所得控除後の給与等の金額
    slip['901'] - slip['941'], # 所得控除の額の金額
    slip['961'], # 源泉徴収税額
    nil, # 未徴収税額
    配偶者控除等 > 0 ? 1 : 2, # 控除対象配偶者の有無 TODO: 従たる給与
    老人控除対象配偶者(slip.dig('profile', 'spouse'), year),
    配偶者控除等, # 配偶者控除の額
    nil, # 控除対象扶養親族の数 特定 主
    nil, # 控除対象扶養親族の数 特定 従
    nil, # 控除対象扶養親族の数 老人 主
    nil, # 控除対象扶養親族の数 老人 上の内訳
    nil, # 控除対象扶養親族の数 老人 従
    nil, # 控除対象扶養親族の数 その他 主
    nil, # 控除対象扶養親族の数 その他 従
    nil, # 障害者の数 特別障害者
    nil, # 障害者の数 上の内訳 NOTE: 同居・同一生計
    nil, # 障害者の数 その他
    slip['912'], # 社会保険料等の額
    nil, # 上の内訳 NOTE: 小規模企業共済等掛金
  ]
end

def 支払を受ける者の詳細(profile, year)
  birth = if profile['birth_date'].is_a?(String)
                 Date.parse(profile['birth_date'])
               else
                 profile['birth_date']
               end
  生年月日 = 和暦(birth)
  扶養対象 = 扶養親族分類(profile['family'], year)

  [
    nil, # 生命保険料の控除額
    nil, # 地震保険料の控除額
    nil, # 住宅借入金等特別控除等の額
    nil, # 旧個人年金保険料の額
    nil, # 配偶者の合計所得
    nil, # 旧長期損害保険料の額
    生年月日[0], # 必須：受給者の生年月日 元号
    生年月日[1], # 必須：受給者の生年月日 年
    生年月日[2], # 必須：受給者の生年月日 月
    生年月日[3], # 必須：受給者の生年月日 日
    nil, # 夫あり（省略する）
    birth.next_year(18) < Date.new(year, 12, -1) ? 0 : 1, # 未成年者
    nil, # 乙欄適用
    nil, # 本人が特別障害者
    nil, # 本人がその他障害者
    nil, # 老年者（省略する）
    nil, # 寡婦
    nil, # 寡夫（省略する）
    Array.new(35), # col90まで未実装
    扶養対象['16才未満'].length,
    nil, # 国民年金保険料等の額
    nil, # 非居住者である親族の数
  ]
end

def 支払を受ける者の扶養情報(profile, year)
  扶養対象 = 扶養親族分類(profile['family'], year)

  [
    profile['tax_id'], # 個人番号
    profile.dig('spouse', 'katakana'), # 控除対象配偶者カナ
    profile.dig('spouse', 'name'), # 控除対象配偶者 氏名
    profile.dig('spouse') ? 00 : nil, # 控除対象配偶者 区分 TODO: 非居住者(01)の設定
    profile.dig('spouse', 'tax_id'), # 控除対象配偶者 個人番号
    [0, 1, 2, 3].map { |i|
      [
        扶養対象.dig('16才以上', i, 'katakana'), # カナ
        扶養対象.dig('16才以上', i, 'name'), # 氏名
        扶養対象.dig('16才以上', i) ? '00' : nil, # 区分 TODO: 非居住者(01)の設定
        扶養対象.dig('16才以上', i, 'tax_id'), # 個人番号
      ]
    },
    [0, 1, 2, 3].map { |i|
      [
        扶養対象.dig('16才未満', i, 'katakana'), # カナ
        扶養対象.dig('16才未満', i, 'name'), # 氏名
        扶養対象.dig('16才未満', i) ? '00' : nil, # 区分 TODO: 非居住者(01)の設定
        扶養対象.dig('16才未満', i, 'tax_id'), # 個人番号
      ]
    },
    Array(扶養対象.dig('16才以上'))[4..]&.map{ |p| "(#{p['tax_id']})#{p['name']}" }&.join('　'), # 5人目以降
    Array(扶養対象.dig('16才未満'))[4..]&.map{ |p| "(#{p['tax_id']})#{p['name']}" }&.join('　'), # 5人目以降
    nil, # 普通徴収
    nil, # 青色専従者
    nil, # 条約免除
    半角変換(profile['katakana']), # 必須：支払を受ける者のフリガナ（半角）
    nil, # 需給者番号
    profile.dig('resident', 'area_code'), # 必須：提出先市町村コード
    profile.dig('resident', 'tax_id'), # 指定番号
  ]
end

# https://www.nta.go.jp/taxes/shiraberu/taxanswer/hotei/7411.htm
# TODO: 役員・弁護士の考慮
def 提出先判定(slip)
  case slip['1']
  when 0 .. 5_000_000
    1
  else
    2
  end
end

def 老人控除対象配偶者(spouse, year)
  return nil if spouse.nil?
  date = spouse['birth_date']
  return 0 if date.nil?

  date = Date.parse(date) if date.is_a?(String)
  date.next_year(70) < Date.new(year, 12, -1) ? 1 : 0
end

def 扶養親族分類(family, year)
  return {} if family.nil?

  { '16才以上' => [], '16才未満' => [] }.tap do |result|
    family.each do |p|
      if !p['birth_date']
        result['16才以上'] << p
      else
        date = p['birth_date']
        date = Date.parse(date) if date.is_a?(String)
        if date.next_year(16) < Date.new(year, 12, -1)
          result['16才以上'] << p
        else
          result['16才未満'] << p
        end
      end
    end
  end
end

def 和暦(date)
  return [nil, nil, nil, nil] if date.nil?

  date = Date.parse(date) if date.is_a?(String)
  case date
  when Date.new(0, 1, 1) .. Date.new(1868, 10, 22)
    raise "Not supported before 明治"
  when Date.new(1868, 10, 23) .. Date.new(1912, 7, 29)
    [3, format("%02d", date.year - 1867), format("%02d", date.month), format("%02d", date.day)]
  when Date.new(1912, 7, 30) .. Date.new(1926, 12, 24)
    [2, format("%02d", date.year - 1911), format("%02d", date.month), format("%02d", date.day)]
  when Date.new(1926, 12, 25) .. Date.new(1989, 1, 7)
    [1, format("%02d", date.year - 1925), format("%02d", date.month), format("%02d", date.day)]
  when Date.new(1989, 1, 8) .. Date.new(2019, 4, 30)
    [4, format("%02d", date.year - 1988), format("%02d", date.month), format("%02d", date.day)]
  else
    [5, format("%02d", date.year - 2018), format("%02d", date.month), format("%02d", date.day)]
  end
end

def 半角変換(str)
  return nil if str.nil? or str.empty?

  result, _e, _s = Open3.capture3("uconv -x 'Fullwidth-Halfwidth'", stdin_data: str)
  result
end
