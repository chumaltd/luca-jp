# frozen_string_literal: true

require 'luca_support'
require 'luca_support/config'

module Luca
  module Jp
    module ItPart
      # タグの出現順序は順不同ではない。eTaxの定義に準拠
      #
      def it_part
        entries = ['<IT VR="1.4" id="IT">']
        entries.concat(['zeimusho']
                         .map{ |key| render_it_tag(key) })
        entries << teisyutsu_day
        entries.concat(['nozeisha_id', 'nozeisha_bango']
                         .map{ |key| render_it_tag(key) })
        entries.concat(['nozeisha_nm_kn', 'nozeisha_nm', 'nozeisha_zip', 'nozeisha_adr_kn', 'nozeisha_adr', 'nozeisha_tel']
                         .map{ |key| render_it_tag(key) })
        entries.concat(['shihon_kin', 'jigyo_naiyo', 'kanpu_kinyukikan']
                         .map{ |key| render_it_tag(key) })
        entries.concat(['daihyo_nm_kn', 'daihyo_nm', 'daihyo_zip', 'daihyo_adr', 'daihyo_tel']
                         .map{ |key| render_it_tag(key) })
        entries << %Q(<TETSUZUKI ID="TETSUZUKI"><procedure_CD>#{@procedure_code}</procedure_CD><procedure_NM>#{@procedure_name}</procedure_NM></TETSUZUKI>)
        entries.concat([jigyo_nendo_from, jigyo_nendo_to, kazei_kikan_from, kazei_kikan_to])
        entries << render_it_tag('keiri_sekininsha')
        entries << '<SHINKOKU_KBN ID="SHINKOKU_KBN"><kubun_CD>1</kubun_CD></SHINKOKU_KBN>'
        entries.concat(['eltax_id'].map{ |key| render_it_tag(key) })
        entries << '</IT>'
        entries.compact.join("\n")
      end

      def render_it_tag(key)
        content = config.dig('jp', 'it_part', key)
        return nil if content.nil?

        case key
        when 'zeimusho'
          content = parse_zeimusho(content)
        when 'nozeisha_tel', 'daihyo_tel'
          content = parse_tel(content)
        when 'nozeisha_zip', 'daihyo_zip'
          content = parse_zip(content)
        when 'nozeisha_bango'
          content = parse_houjinbango(content)
        when 'kanpu_kinyukikan'
          content = parse_kinyukikan(content)
        end

        tag = key.to_s.upcase
        %Q(<#{tag} ID="#{tag}">#{content}</#{tag}>)
      end

      def parse_zeimusho(str)
        items = str.split('-')
        %Q(<gen:zeimusho_CD>#{items[0]}</gen:zeimusho_CD><gen:zeimusho_NM>#{items[1]}</gen:zeimusho_NM>)
      end

      def parse_houjinbango(str)
        %Q(<gen:hojinbango>#{str}</gen:hojinbango>)
      end

      def parse_kinyukikan(str)
        items = str.split('-')
        %Q(<gen:kinyukikan_NM kinyukikan_KB="1">#{items[0]}</gen:kinyukikan_NM><gen:shiten_NM shiten_KB="2">#{items[1]}</gen:shiten_NM><gen:yokin>#{items[2]}</gen:yokin><gen:koza>#{items[3]}</gen:koza>)
      end

      def parse_tel(str)
        num = str.split('-')
        %Q(<gen:tel1>#{num[0]}</gen:tel1><gen:tel2>#{num[1]}</gen:tel2><gen:tel3>#{num[2]}</gen:tel3>)
      end

      def parse_zip(str)
        num = str.split('-')
        %Q(<gen:zip1>#{num[0]}</gen:zip1><gen:zip2>#{num[1]}</gen:zip2>)
      end

      def teisyutsu_day
        %Q(<TEISYUTSU_DAY ID="TEISYUTSU_DAY"><gen:era>#{gengou(@issue_date)}</gen:era><gen:yy>#{wareki(@issue_date)}</gen:yy><gen:mm>#{@issue_date.month}</gen:mm><gen:dd>#{@issue_date.day}</gen:dd></TEISYUTSU_DAY>)
      end

      def jigyo_nendo_from
        %Q(<JIGYO_NENDO_FROM ID="JIGYO_NENDO_FROM"><gen:era>#{gengou(@start_date)}</gen:era><gen:yy>#{wareki(@start_date)}</gen:yy><gen:mm>#{@start_date.month}</gen:mm><gen:dd>#{@start_date.day}</gen:dd></JIGYO_NENDO_FROM>)
      end

      def jigyo_nendo_to
        %Q(<JIGYO_NENDO_TO ID="JIGYO_NENDO_TO"><gen:era>#{gengou(@end_date)}</gen:era><gen:yy>#{wareki(@end_date)}</gen:yy><gen:mm>#{@end_date.month}</gen:mm><gen:dd>#{@end_date.day}</gen:dd></JIGYO_NENDO_TO>)
      end

      def kazei_kikan_from
        %Q(<KAZEI_KIKAN_FROM ID="KAZEI_KIKAN_FROM"><gen:era>#{gengou(@start_date)}</gen:era><gen:yy>#{wareki(@start_date)}</gen:yy><gen:mm>#{@start_date.month}</gen:mm><gen:dd>#{@start_date.day}</gen:dd></KAZEI_KIKAN_FROM>)
      end

      def kazei_kikan_to
        %Q(<KAZEI_KIKAN_TO ID="KAZEI_KIKAN_TO"><gen:era>#{gengou(@end_date)}</gen:era><gen:yy>#{wareki(@end_date)}</gen:yy><gen:mm>#{@end_date.month}</gen:mm><gen:dd>#{@end_date.day}</gen:dd></KAZEI_KIKAN_TO>)
      end
    end
  end
end
