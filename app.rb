require "sinatra"
require 'data_mapper'
#require 'stripe'
require 'sinatra/flash'
require_relative "authentication.rb"

#the following urls are included in authentication.rb
# GET /login
# GET /logout
# GET /sign_up

# authenticate! will make sure that the user is signed in, if they are not they will be redirected to the login page
# if the user is signed in, current_user will refer to the signed in user object.
# if they are not signed in, current_user will be nil

if ENV['DATABASE_URL']
  DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
else
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/app.db")
end

class MenuEntry
	include DataMapper::Resource
	property :id, Serial
	property :cook_id, Integer
	property :meal_title, Text
	property :meal_description, Text
	property :price, Integer 
	property :time, Integer
end

class CustomerOrder
	include DataMapper::Resource
	property :id, Serial
	property :user_id, Integer
	property :chef_id, Integer
	property :description, Text
	property :created_at, DateTime
end

def admin_only!
	if !current_user || !current_user.administrator
		redirect "/"
	end
end

def pro_only!
	if !current_user || !current_user.pro || !current_user.administrator
		redirect "/"
	end
end

def reg_only!
	if !current_user || current_user.pro || current_user.administrator
		redirect "/"
	end
end

def chef_only!
	if !current_user || !current_user.chef
		redirect "/"
	end
end

DataMapper.finalize
MenuEntry.auto_upgrade!
CustomerOrder.auto_upgrade!

#make an admin user if one doesn't exist!
if User.all(administrator: true).count == 0
	u = User.new
	u.email = "admin@admin.com"
	u.password = "admin"
	u.administrator = true
	u.save
end

post "/new_meal/create" do
	authenticate!
	chef_only!
	if params["title"] && params["description"]
		m = MenuEntry.new
		m.cook_id = current_user.id
		m.meal_title = params["title"]
		m.meal_description = params["description"]
		m.price = params["price"]
		m.time = params["time"]
		m.save
		flash[:success] = "Success: You added a new item to your menu."
		redirect "/dashboard"
	else
		flash[:error] = "Error: Missing Information."
		redirect "/new_meal/new"
	end
end

get "/new_meal/new" do
	authenticate!
	chef_only!
	erb :new_meal
end

post '/delete/menu_item' do
	authenticate!
	chef_only!
	item = MenuEntry.get(params["id"])
	item.destroy if item != nil
	flash[:success] = "Success: Item Deleted."
	redirect "/dashboard"
end

# post "/new_order/create" do
# 	authenticate!
# end

# get "/order/new" do
# 	authenticate!
# 	erb :new_order
# end

get "/" do
	erb :index
end

get "/dashboard" do
	authenticate!
	@menus = MenuEntry.all
	erb :dashboard
end