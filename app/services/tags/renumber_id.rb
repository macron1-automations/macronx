module Tags
  class RenumberId
    Result = Struct.new(:tag, :remapped, keyword_init: true)

    Reference = Struct.new(:table, :column, :constraint, keyword_init: true) do
      def label
        "#{table}.#{column}"
      end
    end

    def initialize(old_id:, new_id:)
      @old_id = old_id
      @new_id = new_id
    end

    def call
      from = coerce(old_id, "OLD_ID")
      to = coerce(new_id, "NEW_ID")
      raise ArgumentError, "OLD_ID and NEW_ID must differ" if from == to

      tag = Tag.find_by(id: from)
      raise ArgumentError, "no tag with id #{from}" unless tag

      taken = Tag.find_by(id: to)
      raise ArgumentError, "id #{to} is already taken by '#{taken.name}'" if taken

      remapped = {}
      connection.transaction(requires_new: true) do
        references.each { |ref| connection.execute(drop_constraint_sql(ref)) }
        references.each { |ref| remapped[ref.label] = remap_sql(ref, from, to) }
        tag.update_column(:id, to)
        references.each { |ref| connection.execute(add_constraint_sql(ref)) }
      end

      Result.new(tag: tag, remapped: remapped)
    end

    private

    attr_reader :old_id, :new_id

    def connection
      Tag.connection
    end

    def coerce(value, name)
      id = Integer(value.to_s.strip, exception: false)
      raise ArgumentError, "#{name} must be an integer id" if id.nil? || id < 1
      id
    end

    def remap_sql(ref, from, to)
      connection.update(<<~SQL.squish)
        UPDATE #{quoted_table(ref)} SET #{quoted_column(ref)} = #{to} WHERE #{quoted_column(ref)} = #{from}
      SQL
    end

    def drop_constraint_sql(ref)
      "ALTER TABLE #{quoted_table(ref)} DROP CONSTRAINT #{quoted_name(ref.constraint)}"
    end

    def add_constraint_sql(ref)
      <<~SQL.squish
        ALTER TABLE #{quoted_table(ref)} ADD CONSTRAINT #{quoted_name(ref.constraint)}
        FOREIGN KEY (#{quoted_column(ref)}) REFERENCES tags(id)
      SQL
    end

    def references
      @references ||= connection.select_all(<<~SQL, "Tags::RenumberId references").map do |row|
        SELECT conrelid::regclass::text AS table,
               (SELECT attname FROM pg_attribute WHERE attrelid = conrelid AND attnum = conkey[1]) AS column,
               conname AS constraint
        FROM pg_constraint
        WHERE contype = 'f' AND confrelid = 'tags'::regclass
      SQL
        Reference.new(table: row.fetch("table"), column: row.fetch("column"), constraint: row.fetch("constraint"))
      end
    end

    def quoted_table(ref)
      connection.quote_table_name(ref.table)
    end

    def quoted_column(ref)
      connection.quote_column_name(ref.column)
    end

    def quoted_name(name)
      connection.quote_column_name(name)
    end
  end
end
