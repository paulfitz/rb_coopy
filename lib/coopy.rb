require 'getoptlong'

class Coopy
  def self.usage(code)
      puts "call as:"
      puts "  coopy_diff.rb --format html|csv|tdiff|apply ver1.sqlite ver2.sqlite"
      puts "  coopy_diff.rb ver1.sqlite ver2.sqlite"
      puts "  coopy_diff.rb data.sqlite table1 table2"
      puts "  coopy_diff.rb ver1.sqlite table1 ver2.sqlite table2"
      exit(code)
  end

  def self.run(argv)
    opts = GetoptLong.new(["--format", "-f", GetoptLong::REQUIRED_ARGUMENT])

    if argv.length < 2
      usage(1)
    end

    format = "csv"
    begin
      opts.each do |opt,arg|
        case opt
        when "--format"
          format = arg
        end
      end
    rescue
       usage(1)
    end

    db = SQLite3::Database.new(argv[0])
    sql = SqliteSqlWrapper.new(db)

    name1 = nil
    name2 = nil
    case argv.length
    when 2
      name0 = sql.get_table_names[0]
      db.execute("ATTACH ? AS `__peer_ - _`",argv[1])
      name1 = "main.#{name0}"
      name2 = "__peer_ - _.#{name0}"
    when 3
      name1 = argv[1]
      name2 = argv[2]
    when 4
      name1 = "main.#{argv[1]}"
      db.execute("ATTACH ? AS __peer__",argv[2])
      name2 = "__peer__.#{argv[3]}"
    end

    cmp = SqlCompare.new(sql,name1,name2)

    patches = DiffOutputGroup.new
    case format
    when "html"
      patches << DiffRenderHtml.new
    when "tdiff"
      patches << DiffOutputTdiff.new
    when "csv"
      patches << DiffRenderCsv.new
    when "apply"
      patches << DiffApplySql.new(sql,name1)
    else
      usage(1)
    end

    cmp.set_output(patches)
    
    cmp.apply
    result = patches.to_string
    puts result unless result == ""
    0
  end
end

require 'coopy/diff_output_raw'
require 'coopy/diff_output_tdiff'
require 'coopy/diff_render_html'
require 'coopy/diff_render_csv'
require 'coopy/diff_output_action'
require 'coopy/diff_output_group'
require 'coopy/diff_apply_sql'

require 'coopy/sqlite_sql_wrapper'
require 'coopy/sql_compare'
require 'sqlite3'

