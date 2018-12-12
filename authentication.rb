require 'sinatra'
require_relative "user.rb"

enable :sessions

set :session_secret, 'super secret'

get "/login" do
	erb :"authentication/login"
end


post "/process_login" do
	email = params[:email]
	password = params[:password]

	user = User.first(email: email.downcase)

	if(user && user.login(password))
		session[:user_id] = user.id
		redirect "/"
	else
		flash[:error] = "Invalid Username or Password."
		redirect "/login"
	end
end

get "/logout" do
	session[:user_id] = nil
	redirect "/"
end

get "/sign_up" do
	erb :"authentication/sign_up"
end


post "/register" do
	email = params[:email]
	password = params[:password]
	username = params[:username]
	chef = params[:chef]

	u = User.new
	u.email = params["email"].downcase
	u.password = params["password"]
	u.username = params["username"]
	u.address = params["address"]
	u.city = params["city"].capitalize
	if params["chef"] == "on"
		u.chef = true
	end
	u.save

	session[:user_id] = u.id

	flash[:success] = "Successfully Signed Up."
	redirect "/"
end

#This method will return the user object of the currently signed in user
#Returns nil if not signed in
def current_user
	if(session[:user_id])
		@u ||= User.first(id: session[:user_id])
		return @u
	else
		return nil
	end
end

#if the user is not signed in, will redirect to login page
def authenticate!
	if !current_user
		redirect "/login"
	end
end