# frozen_string_literal: true

require 'date'
require 'luca/jp/version'
require 'luca_support/const'
require 'yaml'

module Luca
  module Jp
    autoload :Kessan, 'luca/jp/kessan'
    autoload :Aoiro, 'luca/jp/aoiro'
    autoload :Syouhizei, 'luca/jp/syouhizei'
    autoload :Chihouzei, 'luca/jp/chihouzei'
    autoload :Common, 'luca/jp/common'
    autoload :ItPart, 'luca/jp/it_part'
    autoload :Sonshitsu, 'luca/jp/sonshitsu'
    autoload :Urikake, 'luca/jp/urikake'
    autoload :Uchiwake, 'luca/jp/uchiwake'
    autoload :Util, 'luca/jp/util'
  end
end
