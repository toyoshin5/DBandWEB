# coding: utf-8
require 'sinatra'
require 'sinatra/reloader'
require 'active_record'

enable :sessions # セッションを有効にする
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'drawOnline.db'
)
class Passwd < ActiveRecord::Base
end 
class Project < ActiveRecord::Base
end


def get_title(url)
    URI.open(url) do |f|
        f.each_line do |line|
            if line =~ /<title>(.*)<\/title>/
                return $1
            end
        end
    end
end


get '/login' do
    #ログインに失敗したらエラーメッセージを表示
    if session[:error]
        @error = session[:error]
        session[:error] = nil
    end
    erb :index
end

post '/login' do
    user = params[:user]
    password = params[:password]
    #パスワードをハッシュ化
    password = Digest::SHA256.hexdigest(password)
    #ユーザidとパスワードが一致したらresにユーザidを入れる
    @res = Passwd.where(:user => user, :password => password).first
    if @res 
        session[:user_id] = @res['id'].to_i  #@res['id'].to_iは@res['id']と取得されるデータが文字列なので整数に変換してsession[:user_id]に代入している。これでsessionに現在ログインしているuserが保持される。
        redirect '/'
    else
        session[:error] = "ユーザ名またはパスワードが違います"
        redirect '/login' #@resがnilだと /loginにリダイレクト
    end
end
post '/draw' do
    projectID = params[:project_id]
    @project = Project.find(projectID)
    @project_author = Passwd.find(@project['user_id']).user
    @now_author = Passwd.find(session[:user_id]).user
    erb :draw
end
#メイン画面
get '/' do
    #セッションにuser_idがあるかどうかでログインしているかどうかを判断している
    if session[:user_id].nil?
        redirect '/login'
    else
        @project = Project.all
        @project_author = []
        @project.each do |project|
            if project['user_id'] == session[:user_id]
                @project_author << "あなた" 
            else
                @project_author << Passwd.find(project['user_id']).user
            end
        end
        @projectCnt = Project.count
        @now_user = session[:user_id]
        erb :main
    end
end
post '/save' do

    imgPng = params["imgpng"]
    imgPng = imgPng.sub(/^data:image\/png;base64,/, "")
    imgPng = Base64.decode64(imgPng)
    #画像を新規保存する
    File.open("public/img/"+params["projectID"]+".png", 'wb') do |f|
        f.write(imgPng)
    end
    redirect '/'
end

get '/create' do
    erb :create
end

post '/create' do
    project = Project.new
    project.title = params[:title]
    project.user_id = session[:user_id]
    project.save
    redirect '/'
end
post '/delete' do
    projectID = params[:project_id]
    project = Project.find(projectID)
    project.destroy
    #ファイルが存在したら
    if File.exist?("public/img/"+projectID+".png")
        File.delete("public/img/"+projectID+".png")
    end
    redirect '/'
end

post '/logout' do
    session[:user_id] = nil
    redirect '/login'
end


#id,user_id,url,