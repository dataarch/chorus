require 'spec_helper'

describe InstanceAccount do
  it "should allow mass-assignment of username and password" do
    InstanceAccount.new(:db_username => 'aname').db_username.should == 'aname'
    InstanceAccount.new(:db_password => 'apass').db_password.should == 'apass'
  end

  describe "validations" do
    let(:gpdb_data_source) { FactoryGirl.build(:gpdb_data_source) }

    it { should validate_presence_of :db_username }
    it { should validate_presence_of :db_password }

    it "validates the uniqueness of owner_id and instance_id" do
      account = InstanceAccount.first
      instance = account.instance
      stub(instance).valid_db_credentials?(anything) { true }
      new_account = instance.accounts.build(:owner => account.owner)
      new_account.should_not be_valid
      new_account.should have_error_on(:owner_id).with_message(:taken)
    end

    it "validates the credentials are valid" do
      account = InstanceAccount.first
      stub(account.instance).valid_db_credentials?(account) { false }
      account.should_not be_valid
      account.should have_error_on(:base).with_message(:INVALID_PASSWORD)
    end

    context "during legacy migration" do
      it "does not validate credentials" do
        account = InstanceAccount.first
        stub(account.instance).valid_db_credentials?(account) { false }
        account.legacy_migrate = true
        account.should be_valid
      end
    end
  end

  describe "associations" do
    it { should belong_to :owner }
    it { should validate_presence_of :owner }

    it { should belong_to :instance }
    it { should validate_presence_of :instance }
  end

  describe "password encryption in the rails database" do
    let(:owner) { users(:admin) }
    let(:instance) { data_sources(:default) }
    let(:password) { "apass" }
    let(:instance_account) do
      account = instance.account_for_user(owner)
      stub(account.instance).valid_db_credentials?(anything) { true }
      account.update_attributes!(:db_password => password, :db_username => 'aname')
      account
    end

    it "stores db_password as encrypted_db_password using the attr_encrypted gem" do
      ActiveRecord::Base.connection.select_values("select encrypted_db_password
                                                  from instance_accounts where id = #{instance_account.id}") do |db_password|
        db_password.should_not be_nil
        db_password.should_not == password
      end
    end
  end

  describe "automatic reindexing" do
    let(:instance) { data_sources(:owners) }
    let(:user) { users(:not_a_member) }

    before do
      stub(Sunspot).index.with_any_args
      any_instance_of(DataSource) { |ds| stub(ds).valid_db_credentials? { true } }
    end

    context "creating a new account" do
      it "should reindex" do
        mock(instance).refresh_databases_later
        InstanceAccount.create!({:owner => user, :instance => instance, :db_username => "foo", :db_password => "bar"}, :without_protection => true)
      end
    end

    context "deleting an account" do
      let(:user) { users(:the_collaborator) }
      let(:account) { instance.account_for_user(user) }
      it "should reindex" do
        mock(account.instance).refresh_databases_later
        account.destroy
      end
    end

    context "updating an account" do
      let(:user) { users(:the_collaborator) }
      let(:account) { instance.account_for_user(user) }

      it "should reindex" do
        mock(account.instance).refresh_databases_later
        account.update_attributes(:db_username => "baz")
      end
    end
  end
end
