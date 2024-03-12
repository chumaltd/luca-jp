# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'fileutils'
require 'pathname'
require 'luca/jp'
require 'luca_book/import'
require 'luca_book/setup'
require 'luca_record/io'
require 'luca_support'

require 'minitest/autorun'

def create_project(dir)
  LucaBook::Setup.create_project('jp', dir)
  deploy("config.yml")
  deploy("config-lucajp.yml")

  prep = %Q([
    {
    "date": "2020-01-01",
    "debit": [
    {
    "label": "現金",
    "amount": 100000
    }
    ],
    "credit": [
    {
    "label": "資本金",
    "amount": 100000
    }
    ]
    }
    ])
  LucaBook::Import.import_json(prep)
  LucaRecord::Base.load_project(Dir.pwd, ext_conf: 'config-lucajp.yml')
end

def deploy(filename, subdir = nil)
  if subdir
    FileUtils.cp("#{__dir__}/#{filename}", Pathname(LucaSupport::CONST.pjdir) / subdir / filename)
  else
    FileUtils.cp("#{__dir__}/#{filename}", Pathname(LucaSupport::CONST.pjdir) / filename)
  end
end

def apply_houjinzei(st_y = 2020, st_m = 1, end_y = 2020, end_m = 12)
  LucaBook::Import.import_json(Luca::Jp::Aoiro.range(st_y, st_m, end_y, end_m).export_json)
  Luca::Jp::Aoiro.range(st_y, st_m, end_y, end_m).kani(export: true)
end

def apply_chihouzei(st_y = 2020, st_m = 1, end_y = 2020, end_m = 12)
  eltax_a, records_for_json = Luca::Jp::Util.eltax_config('reports').map { |report|
    [
      Luca::Jp::Chihouzei.range(st_y, st_m, end_y, end_m)
        .kani(report, export: true),
      Luca::Jp::Chihouzei.range(st_y, st_m, end_y, end_m)
        .export_json(report)
    ]
  }.transpose

  eltax = {}.tap do |h|
    eltax_a.each {|a| h[a[:customer].to_sym] = a }
  end
  eltax_json = JSON.dump(records_for_json)
  LucaBook::Import.import_json(eltax_json)
  [eltax, eltax_json]
end
