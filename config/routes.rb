Rails.application.routes.draw do
  # line_botコントローラーのcallbackアクションのルーティング処理
  post 'callback' => 'line_bot#callback'
  # uptimerobotにURLを渡すためのページ
  get 'hello/index'
end
