require 'bundler'
Bundler.require

class SinatraWardenExample < Sinatra::Base
  use Rack::Session::Cookie, secret: "nothingissecretontheinternet"
  use Rack::Flash, accessorize: [:error, :success]

  use Warden::Manager do |config|
    config.serialize_into_session{|user| user.id }
    config.serialize_from_session{|id| User.get(id) }
    config.scope_defaults :default,
      strategies: [:password],
      action: 'auth/unauthenticated'
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['user'] && params['user']['username'] && params['user']['password']
    end

    def authenticate!
      user = User.first(username: params['user']['username'])

      if user.nil?
        fail!("The username you entered does not exist.")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        fail!("Could not log in")
      end
    end
  end

  get '/' do
    <<-HTML
    <p><a href="/auth/login">Log In</a></p>
    <p><a href="/protected">Protected Page</a></p>
    <p><a href="/auth/logout">Log Out</a></p>
    HTML
  end

  get '/auth/login' do
    <<-HTML
    <p>#{flash[:error]}</p>
    <form action="/auth/login" method="post">
      <p>Username: <input type="text" name="user[username]" /></p>
      <p>Password: <input type="password" name="user[password]" /></p>
      <input type="submit" value="Log In" />
    </form>
    HTML
  end

  post '/auth/login' do
    env['warden'].authenticate!

    flash.success = env['warden'].message

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash.success = 'Successfully logged out'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path]
    puts env['warden.options'][:attempted_path]
    flash.error = env['warden'].message || "You must log in to continue"
    redirect '/auth/login'
  end

  get '/protected' do
    env['warden'].authenticate!

    "Protected Page"
  end
end