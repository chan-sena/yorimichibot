Rails.application.routes.draw do
  # uptimerobotにURLを渡すためのページ
  get 'hello/index'
  # line_botコントローラーのcallbackアクションのルーティング処理
  post 'callback' => 'line_bot#callback'
end
