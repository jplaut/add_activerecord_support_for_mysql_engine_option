module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter < AbstractAdapter
      def create_table(table_name, options = {})
        super(table_name, options.with_indifferent_access.reverse_merge(:options => "ENGINE=InnoDB"))
      end
    end

    class Mysql2Adapter < AbstractMysqlAdapter
      def table_options(table)
        res = self.execute "SHOW TABLE STATUS LIKE '#{table}'"
        engine = res.first[res.fields.index("Engine")]

        options = ''
        options = "ENGINE=#{engine}".inspect if engine

        options
      end

      def column_spec(column, types)
        spec = prepare_column_options(column, types)
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.to_s}: ")}
        spec
      end

      # This can be overridden on a Adapter level basis to support other
      # extended datatypes (Example: Adding an array option in the
      # PostgreSQLAdapter)
      def prepare_column_options(column, types)
        spec = {}
        spec[:name]      = column.name.inspect

        # AR has an optimization which handles zero-scale decimals as integers. This
        # code ensures that the dumper still dumps the column as a decimal.
        spec[:type]      = if column.type == :integer && /^(numeric|decimal)/ =~ column.sql_type
                             'decimal'
                           else
                             column.type.to_s
                           end
        spec[:limit]     = column.limit.inspect if column.limit != types[column.type][:limit] && spec[:type] != 'decimal'
        spec[:precision] = column.precision.inspect if column.precision
        spec[:scale]     = column.scale.inspect if column.scale
        spec[:null]      = 'false' unless column.null
        spec[:default]   = default_string(column.default) if column.has_default?
        spec
      end

      # Lists the valid migration options
      def migration_keys
        [:name, :limit, :precision, :scale, :default, :null]
      end

      private

      def default_string(value)
        case value
        when BigDecimal
          value.to_s
        when Date, DateTime, Time
          "'#{value.to_s(:db)}'"
        else
          value.inspect
        end
      end
    end

    class MysqlAdapter < AbstractMysqlAdapter
      def table_options(table)
        res = self.exec_without_stmt "SHOW TABLE STATUS LIKE '#{table}'"
        engine = res.first.to_hash.first['Engine']

        options = ''
        options = "ENGINE=#{engine}".inspect if engine

        options
      end
    end
  end

  class SchemaDumper
    def table(table, stream)
      columns = @connection.columns(table)
      begin
        tbl = StringIO.new

        # first dump primary key column
        if @connection.respond_to?(:pk_and_sequence_for)
          pk, _ = @connection.pk_and_sequence_for(table)
        elsif @connection.respond_to?(:primary_key)
          pk = @connection.primary_key(table)
        end

        tbl.print "  create_table #{remove_prefix_and_suffix(table).inspect}"
        if columns.detect { |c| c.name == pk }
          if pk != 'id'
            tbl.print %Q(, primary_key: "#{pk}")
          end
        else
          tbl.print ", id: false"
        end
        tbl.print ", force: true"

        options = @connection.table_options(table)
        tbl.print ", options: #{options}" unless options.blank?

        tbl.puts " do |t|"

        # then dump all non-primary key columns
        column_specs = columns.map do |column|
          raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" if @types[column.type].nil?
          next if column.name == pk
          @connection.column_spec(column, @types)
        end.compact

        # find all migration keys used in this table
        keys = @connection.migration_keys

        # figure out the lengths for each column based on above keys
        lengths = keys.map { |key|
          column_specs.map { |spec|
            spec[key] ? spec[key].length + 2 : 0
          }.max
        }

        # the string we're going to sprintf our values against, with standardized column widths
        format_string = lengths.map{ |len| "%-#{len}s" }

        # find the max length for the 'type' column, which is special
        type_length = column_specs.map{ |column| column[:type].length }.max

        # add column type definition to our format string
        format_string.unshift "    t.%-#{type_length}s "

        format_string *= ''

        column_specs.each do |colspec|
          values = keys.zip(lengths).map{ |key, len| colspec.key?(key) ? colspec[key] + ", " : " " * len }
          values.unshift colspec[:type]
          tbl.print((format_string % values).gsub(/,\s*$/, ''))
          tbl.puts
        end

        tbl.puts "  end"
        tbl.puts

        indexes(table, tbl)

        tbl.rewind
        stream.print tbl.read
      rescue => e
        stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
        stream.puts "#   #{e.message}"
        stream.puts
      end

      stream
    end
  end
end

