require 'optparse'

class Coopy

  class Flavor
    attr_accessor :key
    attr_accessor :banner
    attr_accessor :min_length

    def sql_subject?
      [:diff,:patch].include? key
    end

    def sql_object?
      key == :diff
    end

    def can_choose_format?
      key != :patch
    end

    def can_set_output?
      key != :patch
    end

    def default_format
      (key==:patch) ? :apply : :csv
    end
  end

  class OpenStruct
    attr_accessor :format
    attr_accessor :output
  end

  def self.parse(flavor,args)
    options = OpenStruct.new
    options.format = flavor.default_format
    options.output = nil
    OptionParser.new do |opts|
      begin
        opts.banner = flavor.banner
        opts.separator ""
        opts.separator "Specific options"
        if flavor.can_choose_format?
          opts.on("-f","--format [FORMAT]", [:csv, :html, :tdiff, :apply, :stats],
                  "select format (csv,html,tdiff,apply,stats)") do |fmt|
            options.format = fmt
          end
        end
        if flavor.can_set_output?
          opts.on("-o", "--output [FILENAME]",
                  "direct output to a file") do |fname|
            options.output = fname
          end
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
        opts.parse!(args)
        return options
      rescue
        puts "#{$!} (--help for help)"
        exit 1
      end
    end
  end

  def self.core(flavor,argv)
    options = self.parse(flavor,argv)

    if argv.length < flavor.min_length
      self.parse(flavor,["--help"])
      exit(1)
    end

    if flavor.sql_subject?
      db = SQLite3::Database.new(argv[0])
      sql = SqliteSqlWrapper.new(db)
    end

    if flavor.sql_object?
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
    else
      cmp = DiffParser.new(argv[flavor.min_length-1])
    end

    patches = DiffOutputGroup.new
    # patches << DiffOutputRaw.new
    case options.format
    when :html
      patches << DiffRenderHtml.new
    when :tdiff
      patches << DiffOutputTdiff.new
    when :csv
      patches << DiffRenderCsv.new
    when :apply
      patches << DiffApplySql.new(sql,name1)
    when :raw
      patches << DiffOutputRaw.new
    when :stats
      patches << DiffOutputStats.new
    else
      patches << DiffRenderCsv.new
    end

    cmp.set_output(patches)
    
    cmp.apply
    result = patches.to_string
    if result != ""
      if options.output.nil?
        print result
      else
        File.open(options.output,"w") do |f|
          f << result
        end
      end
    end
    0
  end

  def self.diff(argv)
    flavor = Flavor.new
    flavor.key = :diff
    flavor.banner = "Usage: sqlite_diff [options] ver1.sqlite ver2.sqlite"
    flavor.min_length = 2
    self.core(flavor,argv)
  end

  def self.patch(argv)
    flavor = Flavor.new
    flavor.key = :patch
    flavor.banner = "Usage: sqlite_patch [options] db.sqlite patch.csv"
    flavor.min_length = 2
    self.core(flavor,argv)
  end

  def self.rediff(argv)
    flavor = Flavor.new
    flavor.key = :rediff
    flavor.banner = "Usage: sqlite_rediff [options] patch.csv"
    flavor.min_length = 1
    self.core(flavor,argv)
  end
end

require 'coopy/diff_output_raw'
require 'coopy/diff_output_tdiff'
require 'coopy/diff_render_html'
require 'coopy/diff_render_csv'
require 'coopy/diff_output_action'
require 'coopy/diff_output_group'
require 'coopy/diff_output_stats'
require 'coopy/diff_apply_sql'
require 'coopy/diff_parser'

require 'coopy/sqlite_sql_wrapper'
require 'coopy/sql_compare'
require 'sqlite3'

