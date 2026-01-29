# frozen_string_literal: true
require 'luca_salary'
require 'luca_support/const'
require 'luca/jp/util'
require 'zip'

require 'rexml/document'

module LucaSalary
  class JpAdjustment < LucaSalary::Profile

    def self.import(path, id = nil, params = nil)
      s_profile = profiles(id)
      bulk_load(path).each do |o|
        s_profile['spouse']['name'] ||= o['spouse']['name']
        s_profile['spouse']['katakana'] ||= o['spouse']['kana']
        s_profile['spouse']['income'].merge!(o['spouse']['income'])
        if ! s_profile['family'].empty? || ! o['family'].empty?
          s_profile['family'] = merge_family(s_profile['family'].concat(o['family']))
        end
      end
      save(s_profile, 's_profiles')
    end

    def self.profiles(id = nil)
      if id
        list = id_completion(id, basedir: 's_profiles')
        id = if list.length > 1
               raise "#{list.length} entries found for ID: #{id}. abort..."
             else
               list.first
             end
        #merged = find_secure(id, 'profiles') # NOTE for content match by name, birth_date
        find(id, 's_profiles')
      end
    end

    # XMLタグ定義: https://www.nta.go.jp/users/gensen/oshirase/0019004-159.htm
    #
    TAGS = {
      'NTAAPP001' => {
        year: 'xml001_B00020',
        family: {
          root: 'xml001_D00000',   # 扶養親族情報繰り返し
          kana: 'xml001_D00020',   # フリガナ
          name: 'xml001_D00030',   # 氏名
          birth_date: {
            root: 'xml001_D00080', # 生年月日
            year: 'xml001_D00090', # 西暦
            month: 'xml001_D00120', # 月
            day: 'xml001_D00130'   # 日
          },
          income: 'xml001_D00160',  # 本年中の所得の見積額
          elderly: 'xml001_D00140', # 老人扶養親族
          tokutei: 'xml001_D00150', # 特定扶養親族/特定親族
          nonresident: 'xml001_D00170', # 非居住者である親族/控除対象外国外扶養親族
          handicapped: {
            root: 'xml001_D00290', # 障害者である事実
            type: 'xml001_D00300'  # 障害者区分
          }
        }
      },
      'NTAAPP004' => {
        year: 'xml004_B00020',
        spouse: {
          root: 'xml004_D00000',
          kana: 'xml004_D00010',   # フリガナ
          name: 'xml004_D00020',   # 氏名
          income: 'xml004_D00260', # 配偶者の本年中の合計所得金額の見積額
          elderly: 'xml004_D00160', # 老人控除対象配偶者 (1: 該当)
          nonresident: 'xml004_D00170' # 非居住者である配偶者
        }
      }
    }

    def self.parse_xml(xml_set)
      h = { 'spouse' => { 'income' => {} }, 'family' => [] }
      xml_set.each do |xml|
        # ルート要素の属性から様式IDを取得
        form_id = xml.root.name
        tags = TAGS[form_id]
        next unless tags

        year_node = xml.elements["//#{tags[:year]}"]
        year = year_node&.text&.to_i

        # NTAAPP001: 扶養控除等申告書
        if form_id == 'NTAAPP001'
          xml.elements.each("//#{tags[:family][:root]}") do |dep|
            f = {}
            f['name'] = dep.elements[tags[:family][:name]]&.text
            f['kana'] = dep.elements[tags[:family][:kana]]&.text

            bd_tags = tags[:family][:birth_date]
            bd_node = dep.elements[bd_tags[:root]]
            if bd_node
              y = bd_node.elements[bd_tags[:year]]&.text
              m = bd_node.elements[bd_tags[:month]]&.text
              d = bd_node.elements[bd_tags[:day]]&.text
              if y && m && d
                f['birth_date'] = Date.new(y.to_i, m.to_i, d.to_i)
              end
            end

            if year
              dep_income = dep.elements[tags[:family][:income]]&.text
              if dep_income && !dep_income.empty?
                f['income'] = { year => dep_income.to_i }
              end

              elderly = dep.elements[tags[:family][:elderly]]&.text
              if elderly && (elderly == '1' || elderly == '2')
                f['elderly'] = { year => elderly.to_i }
              end

              tokutei = dep.elements[tags[:family][:tokutei]]&.text
              if tokutei && (tokutei == '1' || tokutei == '2')
                f['tokutei'] = { year => tokutei.to_i }
              end

              nonresident = dep.elements[tags[:family][:nonresident]]&.text
              f['nonresident'] = { year => nonresident.to_i } if nonresident == '1'

              hc_tags = tags[:family][:handicapped]
              hc_node = dep.elements[hc_tags[:root]]
              if hc_node
                hc_type = hc_node.elements[hc_tags[:type]]&.text
                if hc_type && !hc_type.empty? && hc_type != '0'
                  f['handicapped'] = { year => hc_type.to_i }
                end
              end
            end

            h['family'] << f
          end
        end

        # NTAAPP004: 配偶者控除等申告書
        if form_id == 'NTAAPP004'
          if year
            spouse = xml.elements["//#{tags[:spouse][:root]}"]
            if spouse
              h['spouse']['name'] = spouse.elements[tags[:spouse][:name]]&.text
              h['spouse']['kana'] = spouse.elements[tags[:spouse][:kana]]&.text

              nonresident = spouse.elements[tags[:spouse][:nonresident]]&.text
              if nonresident == '1'
                h['spouse']['nonresident'] = {} unless h['spouse']['nonresident']
                h['spouse']['nonresident'][year] = nonresident.to_i
              end

              income = spouse.elements[tags[:spouse][:income]]&.text
              h['spouse']['income'][year] = income.to_i if income && !income.empty?

              elderly = spouse.elements[tags[:spouse][:elderly]]&.text
              h['spouse']['elderly'] = '1' if elderly == '1'
            end
          end
        end
      end

      h['family'] = merge_family(h['family']) # 翌年の扶養控除等申告書との重複
      h
    end

    def self.merge_family(family_list)
      merged = {}
      family_list.each do |f|
        key = [f['name'].gsub("　", "").strip, f['birth_date']]
        if merged.key?(key)
          target = merged[key]

          ['income', 'elderly', 'tokutei', 'nonresident', 'handicapped'].each do |field|
            if f[field]
              target[field] ||= {}
              target[field].merge!(f[field])
            end
          end
        else
          merged[key] = f
        end
      end
      merged.values
    end

    def self.bulk_load(path)
      return enum_for(:bulk_load, path) unless block_given?

      has_many = if File.directory?(path)
                   children = Dir.children(path).map { |c| File.join(path, c) }
                   has_subdir = children.any? { |c| File.directory?(c) }
                   has_zip = children.any? { |c| File.file?(c) && File.extname(c).downcase == '.zip' }

                   has_subdir || has_zip
                 elsif File.file?(path)
                   if File.extname(path).downcase == '.zip'
                     false
                   else
                     raise "Unsupported file type: #{path}"
                   end
                 else
                   raise "Path not found: #{path}"
                 end

      if has_many
        # NOTE implement search by content logic
        raise "Multiple import is not supported yet."

        Dir.children(path).sort.map do |child|
          full_path = File.join(path, child)
          if File.directory?(full_path) || (File.file?(full_path) && File.extname(full_path).downcase == '.zip')
            data = load_xml_export(full_path)
            yield parse_xml(data) unless data.empty?
          else
            nil
          end
        end.compact
      else
        data = load_xml_export(path)
        yield parse_xml(data) unless data.empty?
      end
    end

    # 年末調整アプリのエクスポートデータ読み込み(非暗号zipまたはzipを解凍したディレクトリをサポート)
    def self.load_xml_export(path)
      docs = []
      if File.directory?(path)
        Dir.children(path).sort.each do |child|
          full_path = File.join(path, child)
          next if File.directory?(full_path)

          ext = File.extname(child).downcase
          if ext == '.xml'
            begin
              docs << REXML::Document.new(File.read(full_path))
            rescue StandardError => e
              STDERR.puts "#{full_path}: #{e.message}"
            end
          elsif ext == '.zip'
            # skip without warning
          else
            STDERR.puts full_path
          end
        end
        return docs
      end

      if File.file?(path) && File.extname(path).downcase == '.zip'
        Zip::File.open(path) do |zip|
          zip.each do |entry|
            next if entry.directory?

            ext = File.extname(entry.name).downcase
            if ext == '.xml'
              begin
                docs << REXML::Document.new(entry.get_input_stream.read)
              rescue StandardError => e
                STDERR.puts "#{entry.name}: #{e.message}"
              end
            elsif ext == '.zip'
              # skip without warning
            else
              STDERR.puts entry.name
            end
          end
        end
      end
      docs
    end
  end
end
