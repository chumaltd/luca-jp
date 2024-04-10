# frozen_string_literal: true

module Luca #:nodoc:
  module Jp #:nodoc:
    # 勘定科目内訳明細書のレンダリング
    #
    module Uchiwake
      def 預貯金内訳
        @預金 = @bs_data.each.with_object({}) do |(k, v), h|
          next unless /^110[0-9A-Z]/.match(k)
          next unless readable(v || 0) > 0

          h[k] = {
            name: self.class.dict.dig(k)[:label],
            amount: readable(v)
          }
          metadata = uchiwake_account_config(k).first
          if metadata && metadata['name']
            h[k][:name] = metadata['name']
            h[k][:branch] = metadata['branch']
            h[k][:account_type] = metadata['account_type'] || '普通預金'
            h[k][:account_no] = metadata['account_no']
            h[k][:note] = metadata['note']
          end
        end
        render_erb(search_template('yokin-meisai.xml.erb'))
      end

      def 有価証券内訳フォーム
        accounts = uchiwake_account_config('331')
        accounts.concat uchiwake_account_config('332')
        return nil if accounts.length == 0

        'HOI060'
      end

      def 有価証券内訳
        account_codes = uchiwake_account_config('331').map { |account| account['code'].to_s }
        account_codes.concat uchiwake_account_config('332').map { |account| account['code'].to_s }
        return nil if account_codes.length == 0

        @有価証券 = @bs_data.each.with_object({}) do |(k, v), h|
          next unless account_codes.include?(k.to_s)

          inc = debit_amount(k, @start_date.year, @start_date.month, @end_date.year, @end_date.month) || 0
          dec = credit_amount(k, @start_date.year, @start_date.month, @end_date.year, @end_date.month) || 0
          next if v.nil? || (v <= 0 && inc <= 0 && dec <= 0)

          h[k] = {
            name: self.class.dict.dig(k)[:label],
            amount: readable(v),
            diff: readable(inc - dec)
          }
          STDERR.puts "勘定科目内訳書（有価証券）異動の追記が必要： #{h[k][:name]}" unless (inc - dec).zero?

          metadata = uchiwake_account_config(k).first
          if metadata && metadata['name']
            h[k][:name] = metadata['name'][0..9] if metadata['name']
            h[k][:security_purpose] = metadata['security_purpose']
            h[k][:security_genre] = metadata['security_genre']
            h[k][:security_units] = (h[k][:amount].nil? || h[k][:amount].zero?) ? 0 : metadata['security_units']
            h[k][:note] = metadata['note']
          end
          h[k][:security_purpose] ||= 'その他' if /^332/.match(k.to_s)
          h[k][:security_genre] ||= '株式' if /^33[12]/.match(k.to_s)
          h[k][:note] ||= '関係会社株式' if /^332/.match(k.to_s)
        end

        render_erb(search_template('shoken-meisai.xml.erb'))
      end

      def 有価証券合計
        @bs_data.filter { |k, _v| ['331', '332'].include?(k.to_s) }
          .map { |_k, v| readable(v) || 0 }
          .sum
      end

      def 買掛金内訳フォーム
        accounts = uchiwake_account_config('511')
        accounts.concat uchiwake_account_config('514')
        accounts.concat uchiwake_account_config('517')
        return nil if accounts.length == 0

        'HOI090'
      end

      def 買掛金内訳
        account_codes = uchiwake_account_config('511').map { |account| account['code'].to_s }
        account_codes.concat uchiwake_account_config('514').map { |account| account['code'].to_s }
        account_codes.concat uchiwake_account_config('517').map { |account| account['code'].to_s }
        return nil if account_codes.length == 0

        @買掛金 = @bs_data.each.with_object({}) do |(k, v), h|
          next unless account_codes.include?(k.to_s)
          next unless readable(v || 0) > 0

          h[k] = {
            name: self.class.dict.dig(k)[:label],
            amount: readable(v)
          }
          metadata = uchiwake_account_config(k).first
          if metadata && metadata['name']
            h[k][:name] = metadata['name']
            h[k][:payable_type] = self.class.dict.dig(k[0..2], :label)
            h[k][:address] = metadata['address']
            h[k][:note] = metadata['note']
          end
        end

        render_erb(search_template('kaikake-meisai.xml.erb'))
      end

      def 買掛金等合計
        @bs_data.filter { |k, _v| ['511', '514', '517'].include?(k.to_s) }
          .map { |_k, v| readable(v) || 0 }
          .sum
      end

      def 仮受金内訳
        @源泉給与 = readable(@bs_data.dig('5191') || 0)
        @源泉報酬 = readable(@bs_data.dig('5193') || 0)
        render_erb(search_template('kariuke-meisai.xml.erb'))
      end

      def 借入金内訳フォーム
        accounts = uchiwake_account_config('512')
        accounts.concat uchiwake_account_config('712')
        return nil if accounts.length == 0

        'HOI110'
      end

      def 借入金内訳
        account_codes = uchiwake_account_config('512').map { |account| account['code'].to_s }
        account_codes.concat uchiwake_account_config('712').map { |account| account['code'].to_s }
        return nil if account_codes.length == 0

        @借入金 = @bs_data.each.with_object({}) do |(k, v), h|
          next unless account_codes.include?(k.to_s)
          next unless readable(v || 0) > 0

          h[k] = {
            name: self.class.dict.dig(k)[:label],
            amount: readable(v)
          }
          metadata = uchiwake_account_config(k).first
          if metadata && metadata['name']
            h[k][:name] = metadata['name']
            h[k][:address] = metadata['address']
            h[k][:note] = metadata['note']
          end
        end

        render_erb(search_template('kariire-meisai.xml.erb'))
      end

      def 借入金合計
        @bs_data.filter { |k, _v| ['512', '712'].include?(k.to_s) }
          .map { |_k, v| readable(v) || 0 }
          .sum
      end

      def 地代家賃内訳フォーム
        return nil if uchiwake_account_config('C1E').length == 0

        'HOI150'
      end

      def 地代家賃内訳
        account_codes = uchiwake_account_config('C1E').map { |account| account['code'].to_s }
        return nil if account_codes.length == 0

        STDERR.puts "勘定科目内訳書（地代家賃）の支払対象期間の追記が必要"
        @地代家賃 = @bs_data.each.with_object({}) do |(k, v), h|
          next unless account_codes.include?(k)
          next unless readable(v || 0) > 0

          h[k] = {
            name: self.class.dict.dig(k)[:label],
            amount: readable(v)
          }
          metadata = uchiwake_account_config(k).first
          if metadata && metadata['name']
            h[k][:name] = metadata['name']
            h[k][:address] = metadata['address']
            h[k][:rent_type] = metadata['rent_type'] || '家賃'
            h[k][:rent_purpose] = metadata['rent_purpose']
            h[k][:rent_address] = metadata['rent_address']
            h[k][:note] = metadata['note']
          end
        end
        render_erb(search_template('chidai-meisai.xml.erb'))
      end

      def 役員報酬内訳
        STDERR.puts "勘定科目内訳書（役員報酬）の個人別金額の追記が必要"
        @役員報酬 = readable(@pl_data.dig('C11') || 0)
        @給料 = readable(@pl_data.dig('C12') || 0)
        render_erb(search_template('yakuin-meisai.xml.erb'))
      end

      # 雑収入のうち、10万円以上または未収入金とのセット仕訳
      # 雑収入の補助科目のうち、10万円以上
      # 雑損失とその補助科目のうち、10万円以上の仕訳
      #
      def 雑益雑損失内訳フォーム
        @雑益 = LucaBook::List.term(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: 'D16')
                        .data
                        .map { |journal| {
                                 note: journal[:note],
                                 amount: readable(journal[:credit].select { |entry| entry[:code] == 'D16' }
                                   .map { |entry| entry[:amount] }.compact.sum),
                                 tax_refund: journal[:credit].index { |entry| entry[:code] =~ /^150/ }
                               } }
                        .select { |obj| obj[:amount] >= 100_000 || obj[:tax_refund] }
        @pl_data.keys
          .select { |k| k =~ /^D16[0-9A-Z]+/ && @pl_data[k] >= 100_000 }
          .each do |k|
          @雑益.push({
                       note: self.class.dict.dig(k)[:label],
                       amount: @pl_data[k]
                     })
        end
        @雑益 = @雑益.sort_by{ |obj| obj[:amount] }
                .reverse.take(10)

        @雑損失 = LucaBook::List.term(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: 'E16')
                        .data
                        .map { |journal| {
                                 note: journal[:note],
                                 amount: readable(journal[:debit].select { |entry| entry[:code] == 'E16' }
                                   .map { |entry| entry[:amount] }.compact.sum)
                               } }
                        .select { |obj| obj[:amount] >= 100_000 }
        @pl_data.keys
          .select { |k| k =~ /^E16[0-9A-Z]+/ && @pl_data[k] >= 100_000 }
          .each do |k|
          @雑損失.push({
                         note: self.class.dict.dig(k)[:label],
                         amount: @pl_data[k]
                       })
        end
        @雑損失 = @雑損失.sort_by{ |obj| obj[:amount] }
                  .reverse.take(10)
        return nil if @雑益.empty? && @雑損失.empty?

        'HOI160'
      end

      def 雑益雑損失内訳
        return nil if @雑益.empty? && @雑損失.empty?

        STDERR.puts "勘定科目内訳書（雑益雑損失）の内容確認"
        render_erb(search_template('zatsueki-meisai.xml.erb'))
      end
    end
  end
end
