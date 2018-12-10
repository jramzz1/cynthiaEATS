require "sinatra"
require 'data_mapper'
require 'stripe'
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

set :publishable_key, 'pk_test_u0ejpi5VbUvNtY1PhRwQdCyf'
set :secret_key, 'sk_test_zNiT7p9yvBf8SMJUvdxzO8Bp'

Stripe.api_key = settings.secret_key

class MenuEntry
	include DataMapper::Resource
	property :id, Serial
	property :cook_id, Integer
	property :meal_title, Text
	property :meal_description, Text
	property :price, Integer 
	property :time, Integer
	property :delivery_price, Integer
	property :imgData, Text
	property :rating1, Integer, :default => 0
	property :rating2, Integer, :default => 0
	property :rating3, Integer, :default => 0
	property :rating4, Integer, :default => 0
	property :rating5, Integer, :default => 0
	property :rating_overall, Integer, :default => 0
	property :total_ratings, Integer, :default => 0
	property :delivery, Boolean, :default => false
end

class CustomerOrder
	include DataMapper::Resource
	property :id, Serial
	property :plate_id, Integer
	property :plate_price, Integer
	property :plate_time, Integer
	property :plate_title, Text
	property :plate_description, Text
	property :user_id, Integer
	property :chef_id, Integer
	property :created_at, DateTime
	property :delivery, Boolean, :default => false
	property :plate_rated, Boolean, :default => false
	property :chef_rated, Boolean, :default => false
	property :completed, Boolean, :default => false
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

def dollars_to_cents(dollars)
  (100 * dollars.to_r).to_i
end

DataMapper.finalize
MenuEntry.auto_upgrade!
CustomerOrder.auto_upgrade!

#make an admin user if one doesn't exist!
if User.all(administrator: true).count == 0
	u = User.new
	u.email = "admin@admin.com"
	u.password = "admin"
	u.username = "admin"
	u.administrator = true
	u.pro = true
	u.chef = true
	u.save
end

get "/pending/orders" do
	@orders = CustomerOrder.all(chef_id:current_user.id)
	@customers = User.all()
	erb :pending
end

post "/complete/order" do
	order = CustomerOrder.get(params["id"])
	order.update(:completed => true)
	redirect "/pending/orders"
end

post "/save_image" do
  @filename = params[:file][:filename]
  file = params[:file][:tempfile]

  File.open("./public/images/items/#{@filename}", 'wb') do |f|
  	f.write(file.read)
  end

  entry = MenuEntry.get(params["id"])
  entry.update(:imgData => "/images/items/#{@filename}")

	flash[:success] = "Success: image uploaded"
  redirect "dashboard"
end

post "/save_profile" do
  @filename = params[:file][:filename]
  file = params[:file][:tempfile]

  File.open("./public/images/users/#{@filename}", 'wb') do |f|
  	f.write(file.read)
  end

  user = User.get(current_user.id)

  if current_user.chef
  	user.update(:imgDataChef => "/images/users/#{@filename}")
  else
  	user.update(:imgDataUser => "/images/users/#{@filename}")
  end

	flash[:success] = "Success: image uploaded"
  redirect "dashboard"
end

# User Dashboard where most of the magic happens
get "/dashboard" do
	authenticate!

	@menus = MenuEntry.all
	@orders = current_user.customer_orders.reverse.last(4)
	@chefs = User.all(chef: true)
	erb :dashboard
end

# Displays order information before purchasing
get '/display/order/' do
	authenticate!

	@order = MenuEntry.get(params["plate_id"])
	@chef = User.get(params["chef_id"])
	@sub = 1
	@reg = 3

	if params["Delivery"] && params["Delivery"] = "on"
		erb :update_delivery
	end

	erb :place_order
end

post '/update/delivery' do
	erb :place_order
end

# Payment stuff for orders and creates database entry
post '/order/charge' do
	@amount = dollars_to_cents(params["plate_price"])

	c = CustomerOrder.new
	c.user_id = params["customer_id"]
	c.chef_id = params["chef_id"]
	c.plate_description = params["plate_description"]
	c.plate_id = params["plate_id"]
	c.plate_price = params["plate_price"]
	c.plate_time = params["plate_time"]
	c.plate_title = params["plate_title"]
	# c.plate_rated = false
	# c.chef_rated = false

	# Adds $10 to order if delivery
	if params["Delivery"]
		c.delivery = true
		c.plate_price += params["delivery_price"].to_i
		@delivery = dollars_to_cents(params["delivery_price"])
		@amount = @amount + @delivery
	end

	# Adds $1 if user is a subscriber or $3 if not
	if current_user.pro
		c.plate_price += 1
		@amount = @amount + 100
	elsif !current_user.pro
		c.plate_price += 3
		@amount = @amount + 300
	end

	c.save

  	customer = Stripe::Customer.create(
    :email => current_user.email,
    :source  => params[:stripeToken]
  )

  charge = Stripe::Charge.create(
    :amount      => @amount,
    :description => 'Sinatra Charge',
    :currency    => 'usd',
    :customer    => customer.id,
  )

  	flash[:success] = "Success: #{c.plate_title} order placed for: $#{c.plate_price} dollars"
  	redirect "/dashboard"
end

# Upgrade User to pro (monthly subscription)
get '/subscribe' do
	authenticate!

	if current_user.pro
		flash[:error] = "Already a Subscriber"
		redirect "/"
	end

	reg_only!
	erb :subscribe
end

# Payment stuff for subscribers
post '/charge' do
  # Amount ($20) in cents
  @amount = 2000

  customer = Stripe::Customer.create(
    :email => current_user.email,
    :source  => params[:stripeToken]
  )

  charge = Stripe::Charge.create(
    :amount      => @amount,
    :description => 'Sinatra Charge',
    :currency    => 'usd',
    :customer    => customer.id,
  )

  	current_user.pro = true
  	current_user.save

  	flash[:success] = "Success: One Month Subscription Activated"
  	redirect "/"
end

# Submits a chef rating
post "/chef/rating" do
	authenticate!

	chef = User.get(params["chef_id"])

	new_total = chef.total_ratings
	new_total = new_total + 1
	chef.update(:total_ratings => new_total)

	if params["chef_rating"].to_i == 1
		temp1 = chef.rating1
		temp1 = temp1 + 1
		chef.update(:rating1 => temp1)

	elsif params["chef_rating"].to_i == 2
		temp2 = chef.rating2
		temp2 = temp2 +1
		chef.update(:rating2 => temp2)

	elsif params["chef_rating"].to_i == 3
		temp3 = chef.rating3
		temp3 = temp3 +1
		chef.update(:rating3 => temp3)

	elsif params["chef_rating"].to_i == 4
		temp4 = chef.rating4
		temp4 = temp4 +1
		chef.update(:rating4 => temp4)

	elsif params["chef_rating"].to_i == 5
		temp5 = chef.rating5
		temp5 = temp5 +1
		chef.update(:rating5 => temp5)
	end

	product = (((1 * chef.rating1) + (2 * chef.rating2) + (3 * chef.rating3) + (4 * chef.rating4) + (5 * chef.rating5)) / new_total)
	chef.update(:rating_overall => product)
	chef.save

	order = CustomerOrder.get(params["order_id"])
	order.update(:chef_rated => true)
	order.save

	flash[:success] = "Success: You rated the Chef."
	redirect "/dashboard"
end

# Submitts an order rating
post "/order/rating" do
	authenticate!

	item = MenuEntry.get(params["plate_id"])

	new_total = item.total_ratings
	new_total = new_total + 1
	item.update(:total_ratings => new_total)

	if params["plate_rating"].to_i == 1
		temp1 = item.rating1
		temp1 = temp1 + 1
		item.update(:rating1 => temp1)

	elsif params["plate_rating"].to_i == 2
		temp2 = item.rating2
		temp2 = temp2 +1
		item.update(:rating2 => temp2)

	elsif params["plate_rating"].to_i == 3
		temp3 = item.rating3
		temp3 = temp3 +1
		item.update(:rating3 => temp3)

	elsif params["plate_rating"].to_i == 4
		temp4 = item.rating4
		temp4 = temp4 +1
		item.update(:rating4 => temp4)

	elsif params["plate_rating"].to_i == 5
		temp5 = item.rating5
		temp5 = temp5 +1
		item.update(:rating5 => temp5)
	end

	product = (((1 * item.rating1) + (2 * item.rating2) + (3 * item.rating3) + (4 * item.rating4) + (5 * item.rating5)) / new_total)
	item.update(:rating_overall => product)
	item.save

	order = CustomerOrder.get(params["order_id"])
	order.update(:plate_rated => true)
	order.save

	flash[:success] = "Success: You rated the order."
	redirect "/dashboard"
end

# Gets information for new menu item (for chefs)
get "/new_meal/new" do
	authenticate!
	chef_only!

	erb :new_meal
end

# Creates a new menu item (for chefs)
post "/new_meal/create" do
	authenticate!
	chef_only!

	if params["title"] != "" && params["description"] != ""
		m = MenuEntry.new
		m.cook_id = current_user.id
		m.meal_title = params["title"]
		m.meal_description = params["description"]
		m.price = params["price"]
		m.time = params["time"]
		m.delivery_price = params["delivery_price"]

		temp = current_user.chef_items
		temp = temp + 1
		current_user.update(:chef_items => temp)
		m.save

		flash[:success] = "Success: You added a new item to your menu."
		redirect "/dashboard"
	else
		flash[:error] = "Error: Missing Information."
		redirect "/new_meal/new"
	end
end

# Gets all chefs
get "/chefs" do
	authenticate!

	@chefs = User.all(chef: true)
	erb :display_chefs
end

# Gets the menu for a certain chef
get "/chef/menu" do
	authenticate!

	@menu = MenuEntry.all(cook_id:params["id"])
	@chef = params["username"]
	erb :display_menu
end

# Deletes menu item (for chefs)
post '/delete/menu_item' do
	authenticate!
	chef_only!

	item = MenuEntry.get(params["id"])
	item.destroy if item != nil

	flash[:success] = "Success: Menu Item Deleted."
	redirect "/dashboard"
end

# Deletes recent order from dashboard
post '/delete/recent_order' do
	authenticate!

	item = CustomerOrder.get(params["id"])
	item.destroy if item != nil

	flash[:success] = "Success: Recent Order Deleted."
	redirect "/dashboard"
end

# About Us page
get "/about-us" do
	erb :about
end

# Homepage
get "/" do
	erb :index
end
