require 'data_mapper' # metagem, requires common plugins too.

# need install dm-sqlite-adapter
# if on heroku, use Postgres database
# if not use sqlite3 database I gave you
if ENV['DATABASE_URL']
  DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
else
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/app.db")
end

class User
    include DataMapper::Resource
    property :id, Serial
    property :email, String
    property :password, String
    property :username, String
    property :rating1, Integer, :default => 0
    property :rating2, Integer, :default => 0
    property :rating3, Integer, :default => 0
    property :rating4, Integer, :default => 0
    property :rating5, Integer, :default => 0
    property :rating_overall, Integer, :default => 0
    property :total_ratings, Integer, :default => 0
    property :chef_items, Integer, :default => 0
    property :administrator, Boolean, :default => false
    property :pro, Boolean, :default => false
    property :chef, Boolean, :default => false

    def login(password)
    	return self.password == password
    end

    def customer_orders
        return CustomerOrder.all(user_id: id)
    end

    def chef_orders
        return CustomerOrder.all(chef_id: id)
    end
end


# Perform basic sanity checks and initialize all relationships
# Call this when you've defined all your models
DataMapper.finalize

# automatically create the post table
User.auto_upgrade!

