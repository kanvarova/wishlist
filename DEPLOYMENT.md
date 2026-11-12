# Подключённая инфраструктура

- Репозиторий: https://github.com/kanvarova/wishlist — локальная копия клонирована именно из него. Первый коммит создан локально; push требует GitHub-авторизации в среде Codex.
- Supabase: проект `wishlist`, reference `mpdiqavxbxvgacwegsnd`, организация `karishkaanvarova@gmail.com's Org`, регион Singapore (`ap-southeast-1`). Создан с разрешения владельца для бесплатного использования.
- API: https://mpdiqavxbxvgacwegsnd.supabase.co
- [Панель проекта](https://supabase.com/dashboard/project/mpdiqavxbxvgacwegsnd)
- Применена миграция `wishlist_initial_schema`, совпадающая с SQL файлом в репозитории. В базе: 0 продуктов, 0 броней, 7 категорий. RLS включён во всех 7 таблицах public.
- Публичные параметры записаны только в локальную игнорируемую `.env.local`. Для Vercel их ещё нужно добавить через Environment Variables. Публичный ключ можно получить в Supabase → Settings → API Keys. Закрытых ключей в проекте нет.
- Vercel: подключён Hobby аккаунт, но API ещё требует разрешения для workspace `team_XyCe4hw9XFUyobKsZ6VYVknh`. Production URL пока не получен, deployment не подтверждён.

## Обязательные оставшиеся действия владельца

1. Авторизовать GitHub в Codex с правом push к `kanvarova/wishlist`.
2. Открыть свежую одноразовую ссылку Vercel из чата и разрешить доступ к workspace. Для привязки Git также дать Vercel GitHub App доступ к существующему репозиторию.
3. В [Authentication → Users](https://supabase.com/dashboard/project/mpdiqavxbxvgacwegsnd/auth/users) создать свой подтверждённый аккаунт, задавая пароль самостоятельно. Сообщить только email или UUID; пароль не передавать.
4. В Supabase Authentication → Sign In / Providers выключить «Allow new users to sign up». На момент проверки публичная настройка `disable_signup` была `false`. Даже сейчас самостоятельная регистрация **не даёт административных прав**: таблица разрешений закрыта, авторизованных администраторов пока 0.
5. Добавить UUID владельца в `admin_authorization` (команда в README). Затем протестировать вход и живые операции управления; для проверки с подарками использовать отдельную тестовую базу, сохранив production пустым.

## Проверка облачной безопасности

Анонимные HTTPS запросы получили 200 и пустой массив для каталога, 200 и семь категорий; SELECT из reservations, admin_authorization и reservation_throttle получил 401 / permission denied. Вызов save_gift без входа тоже получил 401. Это реальные ответы облачного PostgREST.

Supabase Advisor отмечает ожидаемые особенности архитектуры: [закрытые таблицы с RLS без SELECT-политик](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) и [публично вызываемые SECURITY DEFINER функции](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable). У закрытых таблиц намеренно нет прямого доступа. Публичные функции нужны для каталога и брони без регистрации: они возвращают ограниченные данные либо требуют приватный токен. [Административные SECURITY DEFINER функции](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) дополнительно проверяют auth.uid() по закрытой таблице разрешений. Все функции фиксируют пустой search_path, динамического SQL нет. Эти предупреждения не скрывались и не устранялись расширением прав.
