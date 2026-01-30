# frozen_string_literal: true
require 'fileutils'
require 'luca_salary'
require 'luca_support/const'
require 'luca/jp/util'
require 'rexml/document'
require 'zip'

module LucaSalary
  class JpAdjustment < LucaSalary::Profile

    def self.import(path, id = nil, params = nil)
      tax_ids, names, s_profiles = create_index
      bulk_load(path).each do |o, path|
        s_profile = if id
                      find_profile(id).tap do |p|
                        if p.nil?
                          FileUtils.mkdir_p(path.parent / 'rejected')
                          FileUtils.move(path, path.parent / 'rejected')
                          raise "No entries found for ID: #{id}. abort..."
                        end
                      end
                    else
                      id = search_id(o, tax_ids, names)
                      if id.nil?
                        STDERR.puts "#{o['name']} record not found. skip..."
                        FileUtils.mkdir_p(path.parent / 'rejected')
                        FileUtils.move(path, path.parent / 'rejected')
                        next
                      end
                      s_profiles[id]
                    end
        s_profile = update_profile(s_profile, o)
        save(s_profile, 's_profiles')
      end
    end

    def self.create_index
      tax_ids = {}
      names = {}
      profiles = {}
      all('profiles').each do |p|
        profile = find_secure(p['id'], 'profiles')
        if profile['tax_id']
          tax_ids[profile['tax_id'].to_s] = p['id']
        end
        key = [profile['name'].gsub("　", "").strip, profile['birth_date'].to_s]
        names[key] = p['id']
        s_profile = find(p['id'], 's_profiles')
        profiles[profile['id']] = s_profile
      end
      [tax_ids, names, profiles]
    end

    def self.find_profile(id_fragment)
      list = id_completion(id_fragment, basedir: 's_profiles')
      if list.length > 1
        STDERR.puts "#{list.length} entries found for ID: #{id_fragment}. abort..."
        return nil
      end

      id = list.first
      find(id, 's_profiles')
    end

    def self.update_profile(previous, imported)
      previous['tax_id'] ||= imported['tax_id']
        previous['name'] ||= imported['name']
        previous['katakana'] ||= imported['kana']
        previous['birth_date'] ||= imported['birth_date']

        if imported['spouse'] && !imported['spouse'].empty?
          if same_person?(previous['spouse'], imported['spouse'])
            # NOTE imported['spouse']をベースにし、incomeだけマージ
            income = (previous['spouse']['income'] || {}).merge(imported['spouse']['income'])
            previous['spouse'] = imported['spouse']
            previous['spouse']['income'] = income
          else
            previous['spouse'] = imported['spouse']
          end
        end

        if !imported['family'].empty?
          previous['family'] = imported['family'].map do |latest|
            registered = previous['family'].find { |m| same_person?(m, latest) }
            if registered
              ['income', 'elderly', 'tokutei', 'nonresident', 'handicapped'].each do |k|
                latest[k] = registered[k].merge(new_member[k]) if registered[k] && new_member[k]
                latest[k] ||= registered[k]
              end
            end
            latest
          end
        end
      previous
    end

    # XMLタグ定義: https://www.nta.go.jp/users/gensen/oshirase/0019004-159.htm
    #
    TAGS = {
      'NTAAPP001' => {
        year: 'xml001_B00020',
        id: 'xml001_B00170',     # マイナンバー
        kana: 'xml001_B00150',   # フリガナ
        name: 'xml001_B00160',   # 氏名
        birth_date: {
          root: 'xml001_B00230', # 生年月日
          year: 'xml001_B00240', # 西暦
          month: 'xml001_B00270', # 月
          day: 'xml001_B00280'   # 日
        },
        family: {
          root: 'xml001_D00000',   # 扶養親族情報繰り返し
          id: 'xml001_D00040',     # マイナンバー
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
          id: 'xml004_D00030',     # マイナンバー
          kana: 'xml004_D00010',   # フリガナ
          name: 'xml004_D00020',   # 氏名
          income: 'xml004_D00260', # 配偶者の本年中の合計所得金額の見積額
          elderly: 'xml004_D00160', # 老人控除対象配偶者 (1: 該当)
          nonresident: 'xml004_D00170' # 非居住者である配偶者
        }
      }
    }

    def self.parse_xml(xml_set)
      h = { 'spouse' => {}, 'family' => [] }
      xml_set.each do |xml|
        # ルート要素の属性から様式IDを取得
        form_id = xml.root.name
        tags = TAGS[form_id]
        next unless tags

        year_node = xml.elements["//#{tags[:year]}"]
        year = year_node&.text&.to_i

        if form_id == 'NTAAPP001'
          tags = TAGS[form_id]
          h['tax_id'] ||= xml.elements["//#{tags[:id]}"]&.text
          h['name'] ||= xml.elements["//#{tags[:name]}"]&.text
          h['kana'] ||= xml.elements["//#{tags[:kana]}"]&.text
          bd_tags = tags[:birth_date]
          bd_node = xml.elements["//#{bd_tags[:root]}"]
          if bd_node
            y = bd_node.elements[bd_tags[:year]]&.text
            m = bd_node.elements[bd_tags[:month]]&.text
            d = bd_node.elements[bd_tags[:day]]&.text
            if y && m && d
              h['birth_date'] = Date.new(y.to_i, m.to_i, d.to_i)
            end
          end
          h['family'] << parse_family(xml, year)
        end

        if form_id == 'NTAAPP004' && year
          h['spouse'] = parse_spouse(xml, year)
        end
      end

      h['family'] = merge_family(h['family']) # 翌年の扶養控除等申告書との重複
      h
    end

    def self.search_id(query, tax_ids, names)
      id = tax_ids[query['tax_id']] if query['tax_id']
      return id if id

      key = [query['name'].gsub("　", "").strip, query['birth_date'].to_s]
      names[key]
    end

    def self.same_person?(p1, p2)
      return false if p1.nil? || p2.nil? || p1.empty? || p2.empty?

      if p1['tax_id'] && p2['tax_id']
        return p1['tax_id'].to_s == p2['tax_id'].to_s
      end

      n1 = p1['name'].to_s.gsub('　', '').strip
      n2 = p2['name'].to_s.gsub('　', '').strip
      bd1 = p1['birth_date'].to_s
      bd2 = p2['birth_date'].to_s

      n1 == n2 && bd1 == bd2
    end

    # NTAAPP004: 配偶者控除等申告書
    def self.parse_spouse(xml, year)
      tags = TAGS['NTAAPP004']
      spouse = xml.elements["//#{tags[:spouse][:root]}"]
      return {} if ! spouse

      { 'income' => {} }.tap do |h|
        h['tax_id'] = spouse.elements[tags[:spouse][:id]]&.text
        h['name'] = spouse.elements[tags[:spouse][:name]]&.text
        h['kana'] = spouse.elements[tags[:spouse][:kana]]&.text

        nonresident = spouse.elements[tags[:spouse][:nonresident]]&.text
        if nonresident == '1'
          h['nonresident'] = {} unless h['nonresident']
          h['nonresident'][year] = nonresident.to_i
        end

        income = spouse.elements[tags[:spouse][:income]]&.text
        h['income'][year] = income.to_i if income && !income.empty?

        elderly = spouse.elements[tags[:spouse][:elderly]]&.text
        h['elderly'] = '1' if elderly == '1'
      end
    end

    # NTAAPP001: 扶養控除等申告書
    def self.parse_family(xml, year)
      tags = TAGS['NTAAPP001']
      h = []
      xml.elements.each("//#{tags[:family][:root]}") do |dep|
        f = {}
        f['tax_id'] = dep.elements[tags[:family][:id]]&.text
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
        h << f
      end
      h
    end

    def self.merge_family(family_list)
      merged = {}
      family_list.flatten.each do |f|
        key = if f['tax_id']
                f['tax_id']
              else
                [f['name'].gsub("　", "").strip, f['birth_date'].to_s]
              end
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
        Dir.children(path).sort.map do |child|
          full_path = File.join(path, child)
          if File.directory?(full_path) || (File.file?(full_path) && File.extname(full_path).downcase == '.zip')
            data = load_xml_export(full_path)
            yield(parse_xml(data), Pathname(full_path)) unless data.empty?
          else
            nil
          end
        end.compact
      else
        data = load_xml_export(path)
        yield(parse_xml(data), Pathname(path)) unless data.empty?
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
