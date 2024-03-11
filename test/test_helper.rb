# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'fileutils'
require 'pathname'
require 'luca_book/setup'
require 'luca_record/io'
require 'luca_support'

require 'minitest/autorun'

def create_project(dir)
  LucaBook::Setup.create_project('jp', dir)
  FileUtils.cp("#{__dir__}/config.yml", Pathname(LucaSupport::CONST.pjdir))

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
end

def deploy(filename, subdir = nil)
  if subdir
    FileUtils.cp("#{__dir__}/#{filename}", Pathname(LucaSupport::CONST.pjdir) / subdir / filename)
  else
    FileUtils.cp("#{__dir__}/#{filename}", Pathname(LucaSupport::CONST.pjdir) / filename)
  end
end
