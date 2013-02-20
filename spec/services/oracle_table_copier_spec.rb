require 'spec_helper'

describe OracleTableCopier do
  let(:user) { "some guy" }
  let(:account) { "some guy's account" }
  let(:source_dataset) { datasets(:oracle_table) }
  let(:destination_schema) { schemas(:default) }
  let(:destination_table_name) { "hello" }
  let(:destination_connection) { Object.new }
  let(:source_connection) { Object.new }
  let(:sample_count) { nil }
  let(:truncate) { false }

  let(:copier) do
    OracleTableCopier.new(
        {
            :source_dataset => source_dataset,
            :destination_schema => destination_schema,
            :destination_table_name => destination_table_name,
            :user => user,
            :sample_count => sample_count,
            :truncate => truncate
        }
    )
  end

  describe "initialization" do

    before do
      stub(source_dataset).connect_as(user) { source_connection }
      stub(source_dataset).connect_with(account) { source_connection }
      stub(source_dataset.data_source).account_for_user! { account }

      stub(destination_schema).connect_as(user) { destination_connection }
      stub(destination_schema).connect_with(account) { destination_connection }
    end

    describe "initialize_destination_table" do
      subject { copier.initialize_destination_table }

      context "when it doesn't exist yet" do
        before do
          stub(destination_connection).table_exists?(destination_table_name) { false }
          stub(source_connection).column_info(source_dataset.name, anything) do
            [
                {:attname => "BIN_DOUBLE", :format_type => "BINARY_DOUBLE"},
                {:attname => "BIN_FLOAT", :format_type => "BINARY_FLOAT"},
                {:attname => "CHARACTER", :format_type => "CHAR"},
                {:attname => "CHAR_BLOB", :format_type => "CLOB"},
                {:attname => "DAY", :format_type => "DATE"},
                {:attname => "DECIMAL_COL", :format_type => "DECIMAL"},
                {:attname => "INTEGER_COL", :format_type => "INT"},
                {:attname => "LONG_COL", :format_type => "LONG"},
                {:attname => "NUMBER_COL", :format_type => "NUMBER"},
                {:attname => "ROW_ID", :format_type => "ROWID"},
                {:attname => "TIMESTAMP_COL", :format_type => "TIMESTAMP(6)"},
                {:attname => "UNICODE_CHAR", :format_type => "NCHAR"},
                {:attname => "UNICODE_CLOB", :format_type => "NCLOB"},
                {:attname => "UNICODE_VARCHAR", :format_type => "NVARCHAR2"},
                {:attname => "UNIVERSAL_ROW_ID", :format_type => "UROWID"},
                {:attname => "VARIABLE_CHARACTER", :format_type => "VARCHAR"},
                {:attname => "VARIABLE_CHARACTER_2", :format_type => "VARCHAR2"}
            ]
          end
          stub(source_connection).primary_key_columns(source_dataset.name) { primary_keys }
        end

        let(:primary_keys) { [] }

        it "creates it with the correct columns" do
          columns = [
              %Q{"BIN_DOUBLE" float8},
              %Q{"BIN_FLOAT" float8},
              %Q{"CHARACTER" character},
              %Q{"CHAR_BLOB" text},
              %Q{"DAY" timestamp},
              %Q{"DECIMAL_COL" float8},
              %Q{"INTEGER_COL" numeric},
              %Q{"LONG_COL" text},
              %Q{"NUMBER_COL" numeric},
              %Q{"ROW_ID" text},
              %Q{"TIMESTAMP_COL" timestamp},
              %Q{"UNICODE_CHAR" character},
              %Q{"UNICODE_CLOB" text},
              %Q{"UNICODE_VARCHAR" character varying},
              %Q{"UNIVERSAL_ROW_ID" text},
              %Q{"VARIABLE_CHARACTER" character varying},
              %Q{"VARIABLE_CHARACTER_2" character varying},
          ]
          mock(destination_connection).create_table(destination_table_name, columns.join(', '), 'DISTRIBUTED RANDOMLY')
          copier.initialize_destination_table
        end

        context "with a primary key" do
          let(:primary_keys) { %w(hi bye) }

          it "should add the primary key clause to the columns and distribute correctly" do
            mock(destination_connection).create_table(destination_table_name, satisfy { |arg| arg.ends_with?(", PRIMARY KEY(\"hi\", \"bye\")") }, %Q{DISTRIBUTED BY("hi", "bye")})
            subject
          end
        end
      end

      context "when it exists" do
        before do
          stub(destination_connection).table_exists?(destination_table_name) { true }
        end

        it "should not create it" do
          dont_allow(destination_connection).create_table.with_any_args
          dont_allow(destination_connection).truncate_table.with_any_args
          subject
        end

        context "when it should be truncated" do
          let(:truncate) { true }
          it "should truncate" do
            mock(destination_connection).truncate_table(destination_table_name)
            subject
          end
        end
      end
    end
  end

  describe "run", :oracle_integration do
    let(:source_dataset) { OracleIntegration.real_schema.datasets.first }
    let(:user) { users(:owner) }

    xit "should insert the data into the destination table" do
      copier.run
      #get_rows(destination_database_url, "SELECT * FROM #{destination_table_fullname}").length.should == 2
    end
  end
end