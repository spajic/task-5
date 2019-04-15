# Задание №5

## Upd

**При выполнении задания стали возникать вопросы, вот несколько уточнений.**

### `Server-push` и `HTTP/2` достаточно настроить и проверить *локально*.

`NGrok` в бесплатной версии проксирует траффик только по `HTTP/1.1`, поэтому если вы выставите свой локальный сервер в интернет через `NGrok` и выполните анализ `WebPageTest`, то там всё будет работать через `HTTP/1.1`.

### Сделать и проанализировать отчёт `WebPageTest` для `https://dev.to` предлагается на их продовом сайте.

### Чеклист для сдачи задания

- [x] Скриншот `DevTools` с работающим `server-push`
- [x] Файлы кода `dev.to`, которые вы изменили, чтобы сделать `server-push` картинок (комитьте итоговые версии файлов, затронутых изменениями)
- [x] Конфиг `NGinx`
- [x] Описание со сравнением *восприятия* работы сайта с `inline`-картинками, обычными картинками и `server-pushed` картинками (попробовать разные варианты локально)
- [x] Гипотезы о возможных оптимизациях `dev.to` по результатам анализа отчёта `WebPageTest` на их проде; подумайте в контексте интуиции работы с `server-push`, которую вы получили
- [ ] Бонус про `Falcon`

## Цели задания
В этом задании немного попрактикуемся с `HTTP/2` в `Rails`.

Польза:
- научиться настраивать `HTTPS` для локального `Rails`-приложения
- научиться настраивать `HTTP/2` `reverse proxy` с поддержкой `server-push`
- научиться делать `server-push`, сравнить его с `inlining`

## ToDo

Работать будем на примере проекта `dev.to` из задания №3.

Ресурсы:
- http://railscasts.com/episodes/357-adding-ssl?view=asciicast - старый, но очень понятный `RailsCast`
- https://github.com/FiloSottile/mkcert - инструмент для настройки локальных сертификатов одной командой
- https://www.nginx.com/blog/nginx-1-13-9-http2-server-push/ - настройка `http2-server-push` в `NGinx`.
- https://github.com/surma/http2-push-detect - утилита для проверки `server-push`

### Шаг 1. Настроить сертификат для локального HTTPS
Можно сделать с использованием `mkcert`

### Шаг 2. Настраиваем NGinx как reverse-proxy
Установить или обновить `NGinx`.

Конфигурируем `NGinx` так, чтобы он принимал `https`-запросы `https://localhost` и ходил в `upstream` на `http://localhost:3000`.

```
server {
  listen       443 ssl;
  server_name  localhost;

  ssl_certificate      /path/to/localhost.pem;
  ssl_certificate_key  /path/to/localhost-key.pem;
  ssl_session_timeout  5m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:DES-CBC3-SHA:!RC4:!aNULL:!eNULL:!MD5:!EXPORT:!EXP:!LOW:!SEED:!CAMELLIA:!IDEA:!PSK:!SRP:!SSLv:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
  ssl_prefer_server_ciphers   on;

  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_redirect off;
    proxy_pass http://127.0.0.1:3000;
  }
}
```

На этом шаге браузер должен успешно открывать `https://localhost`

### Шаг 3. Настроить HTTP/2 и server-push
Дополняем конфиг `NGinx` поддержкой `HTTP/2` и `server-push`

```
server {
  listen  443 http2 ssl;
  #...

  location /{
    http2_push_preload on;
    #...
  }
}
```

### Шаг 4. Поэксперементировать с HTTP/2 server-push
На главном экране в мобильном виде `dev.to` есть ряд картинок:
- `connect.svg`
- `bell.svg`
- `menu.svg`
- `stack.svg`
- `lightning.svg`

![Screenshot](https://github.com/spajic/task-5/blob/master/screenshot.png?raw=true)

Картинки из меню: `connect.svg`, `bell.svg`, `menu.svg` – заинлайнены.
Картинки `stack.svg` и `lightning.svg` – нет.

Попробуйте перезагружать эту страницу и посмотреть как рендерятся эти картинки при перезагрузке.

Дальше, давайте попробуем двинуться в сторону подхода `HTTP/2` и не будем инлайнить `svg`, а подключим их как обычные картинки.

Например, `image_tag("bell.svg", size: "100% * 100%")`

Теперь давайте добавим `server-push`!

Для этого нам нужно установить специальные заголовки:

```
# stories_controller.rb
def index
  push_headers = [
    "<#{view_context.asset_path('bell.svg')}>; rel=preload; as=image",
    "<#{view_context.asset_path('menu.svg')}>; rel=preload; as=image",
    "<#{view_context.asset_path('connect.svg')}>; rel=preload; as=image",
    "<#{view_context.asset_path('stack.svg')}>; rel=preload; as=image",
    "<#{view_context.asset_path('lightning.svg')}>; rel=preload; as=image",
  ]
  response.headers['Link'] = push_headers.join(', ')
  # ...
end
```

На этом шаге нужно убедиться, что `server-push` работает.

В `Chrome` `DevTools` в панели `Network` вы должны увидеть, что запросы к этим картинкам делаются по протоколу `h2`, а `Initiator` = `Push/Other`

Ещё один способ проверить работу `server-push` - утилита `http2-push-detect`

```
http2-push-detect https://localhost
Receiving pushed resource: /assets/bell.svg
Receiving pushed resource: /assets/menu.svg
Receiving pushed resource: /assets/connect.svg
Receiving pushed resource: /assets/stack.svg
Receiving pushed resource: /assets/lightning.svg
```

Теперь поэксперементируйте, попробуйте включать и выключать `server-push` для тех или иных картинок и оцените, как это сказывается на их рендеринге.

## Шаг 5. Аудит dev.to
Теперь, когда у вас сформировалась интуиция по работе с `HTTP/2` и `server-push`, постройте и проанализируйте отчёт `WebPageTest` для сайте `dev.to`.

Видите ли вы какие-то возможности использовать возможности `HTTP/2` для оптимизации `dev.to`, исходя из отчётов `WPT`?

## Bonus
Сервер `Falcon` https://github.com/socketry/falcon утверждает, что может сервить `Rails`-приложения и из коробки поддерживает `HTTP/2`.

Попробуйте настроить работу `dev.to` с `server-push` для `Falcon`.

Сделайте сравнительный бенчмарк `puma` и `falcon` на примере главной страницы `dev.to`.

## Как сдать задание
Нужно сделать `PR` в этот репозиторий с вашими изменениями кода `dev.to`, конфигом `NGinx` и описанием.

В описании сравните рендеринга картинок с `inlining`, `server-push`, и без того и другого.

Напишите ваши выводы по результатам аудита `dev.to` через `WebPageTest`.

Ну и вообще, напишите о том, что интересного вы узнаете при выполнении задания.

