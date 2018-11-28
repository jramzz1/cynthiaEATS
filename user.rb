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
    property :favorite_food, String
    property :created_at, DateTime
    property :administrator, Boolean, :default => false
    property :pro, Boolean, :default => false
    property :chef, Boolean, :default => false

    def login(password)
    	return self.password == password
    end

    # def free
    #     return self.pro == false
    # end

    # def chef
    #     return self.chef == false
    # end

    # def pro
    #     return self.pro == true
    # end

    # def administrator
    #     return self.administrator == true
    # end
end

# Perform basic sanity checks and initialize all relationships
# Call this when you've defined all your models
DataMapper.finalize

# automatically create the post table
User.auto_upgrade!

