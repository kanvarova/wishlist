# Подключённая инфраструктура

- Сайт: **https://wishlist-kanvarova.vercel.app**. Проверен 13 ноября 2026 года без login cookies: `/`, `/admin`, прямая gift-ссылка и `/og.png` отвечают HTTPS 200. Браузер загрузил пустой каталог и категории из живой Supabase.
- Репозиторий: https://github.com/kanvarova/wishlist — полный исходный проект опубликован именно в нём. Локальная main синхронизирована с origin/main. Исходная рабочая версия приложения: `b0fe0a0b0f49863ceb6d13fa22dfc99f40a4762a`.
- Supabase: проект `wishlist`, reference `mpdiqavxbxvgacwegsnd`, личная организация Free, регион Singapore (`ap-southeast-1`). Создан с разрешения владельца для бесплатного использования.
- API: https://mpdiqavxbxvgacwegsnd.supabase.co
- [Панель проекта](https://supabase.com/dashboard/project/mpdiqavxbxvgacwegsnd)
- Применена миграция `wishlist_initial_schema`, совпадающая с SQL файлом в репозитории. В базе: 0 продуктов, 0 броней, 7 категорий. RLS включён во всех 7 таблицах public.
- Публичные параметры настроены в локальной игнорируемой `.env.local` и в Vercel Environment Variables. Закрытых ключей в проекте нет. Production Site URL в Supabase настроен на адрес сайта.
- Владелец создал подтверждённый аккаунт; ему выданы права через закрытую `admin_authorization`. Публичная регистрация отключена; реальный Auth API возвращает `disable_signup: true`.
- Vercel Hobby: проект `prj_VSyrSji5Mw4kkZKkrSMMt1B3yXGw`, production deployment `dpl_H2C4i899caR8qToh4HnZyiXp785h`, состояние **READY**. Node.js настроен на 24.x. Production открыт посетителям; защита Vercel сохранена для preview.
- [GitHub Actions](https://github.com/kanvarova/wishlist/actions/runs/43274773023): установка с frozen lockfile, 22 проверки и стандартная Vite production-сборка завершились успешно.

## Автоматическое развёртывание и приёмка

1. Публикация выполнена через API из файлов указанного GitHub-коммита. Автоматический Git deploy пока не подключён: Vercel вернул «You need to add a Login Connection to your GitHub account first». Для будущего автоматического деплоя откройте настройки своего аккаунта Vercel → Authentication → Login Connections → GitHub, затем Project → Settings → Git → Connect Git Repository и выберите **kanvarova/wishlist**. Не создавайте новый репозиторий или новый Vercel проект. Содержимое вишлиста уже меняется из панели без Git и пересборки.
2. Войдите на https://wishlist-kanvarova.vercel.app/admin своим паролем. Пароль выбирал только владелец; агент его не получал. Успешный вход и операции в интерфейсе после него требуют проверки владельцем — они не объявлены проверенными по одному лишь созданию аккаунта.
3. Проверки с тестовыми подарками выполняются в отдельной тестовой базе. Production оставлен пустым для настоящих подарков владельца. Текущие ограничения проверки перечислены в `VERIFICATION.md`.

## Проверка облачной безопасности

Анонимные HTTPS запросы получили 200 и пустой массив для каталога, 200 и семь категорий; SELECT из reservations, admin_authorization и reservation_throttle получил 401 / permission denied. Вызов save_gift без входа тоже получил 401. Это реальные ответы облачного PostgREST.

Supabase Advisor отмечает ожидаемые особенности архитектуры: [закрытые таблицы с RLS без SELECT-политик](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) и [публично вызываемые SECURITY DEFINER функции](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable). У закрытых таблиц намеренно нет прямого доступа. Публичные функции нужны для каталога и брони без регистрации: они возвращают ограниченные данные либо требуют приватный токен. [Административные SECURITY DEFINER функции](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) дополнительно проверяют auth.uid() по закрытой таблице разрешений. Все функции фиксируют пустой search_path, динамического SQL нет. Эти предупреждения не скрывались и не устранялись расширением прав.
