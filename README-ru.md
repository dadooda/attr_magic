
# Инструменты для реализации атрибутов-вычислителей

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [Введение](#введение)
  - [Что даёт AttrMagic?](#что-даёт-attrmagic)
- [Установка](#установка)
- [Пример использования](#пример-использования)
  - [`#igetset`](#igetset)
  - [`#require_attr`](#require_attr)
  - [`#igetwrite`](#igetwrite)
- [Copyright](#copyright)

<!-- /code_chunk_output -->

## Введение

*An English version of this text is also available: [README.md](README.md).*

Атрибут-вычислитель (lazy attribute) — это метод-accessor, который производит некое вычисление при первом вызове,
мемоизирует результат в instance-переменную и возвращает результат. Например:

```ruby
class Person
  # @return [String]
  attr_accessor :first_name, :last_name

  attr_writer :full_name, :is_admin

  def initialize(attrs = {})
    attrs.each { |k, v| public_send("#{k}=", v) }
  end

  # @return [String]
  def full_name
    @full_name ||= begin
      [first_name, last_name].compact.join(" ").strip
    end
  end

  # @return [Boolean]
  def is_admin
    return @is_admin if defined? @is_admin
    @is_admin = !!full_name.match(/admin/i)
  end
end
```

В примере выше `#full_name` и `#is_admin` — атрибуты-вычислители.

### Что даёт AttrMagic?

Классам, содержащим атрибуты-вычислители, AttrMagic даёт:

1. `#igetset` и `#igetwrite` для простой мемоизации любых значений, включая `false` и `nil`.
2. `#require_attr` для валидации атрибутов, от которых зависит результат данного вычисления.

## Установка

Добавляем в `Gemfile` нашего проекта:

```ruby
gem "attr_magic"
#gem "attr_magic", git: "https://github.com/dadooda/attr_magic"
```

## Пример использования

Чтобы использовать фичу, загружаем её в класс:

```ruby
class Person
  AttrMagic.load(self)
  …
end
```

Методы AttrMagic теперь доступны в классе `Person`.
Теперь рассмотрим, какие инструменты стали нам доступны.

### `#igetset`

В примере выше метод `#full_name` мемоизирует результат оператором `||=`.
Это вполне приемлемо, ведь результат вычисления — строка.

А вот реализация `#is_admin` гораздо более громоздка, ведь результат
может быть вычислен как `false`, стало быть `||=` не подойдёт.

Оба метода можно переписать с использованием `#igetset`:

```ruby
class Person
  …
  def full_name
    igetset(__method__) { [first_name, last_name].compact.join(" ").strip }
  end

  def is_admin
    igetset(__method__) { !!full_name.match(/admin/i) }
  end
end
```

Методы приобрели короткий, единообразный, легко читаемый вид.
Теперь вычисление в `#is_admin` отчётливо видно, тогда как ранее оно тонуло в повторах
*is_admin* внутри метода, который и так назван этим словом.

### `#require_attr`

В примере выше метод `#first_name` возвращает пустую строку, даже если атрибуты
`first_name` и `last_name` не присвоены или пусты.

С точки зрения внятности это поведение «на грани фола».
Ведь, скорее всего, результат `#full_name` будет выводиться в блоке информации о персоне или при обращении к персоне.
Пустая строка, даже правомерно вычисленная, вызовет в этой ситуации, как минимум, непонимание.

Конечно, экземпляр `Person` не виноват, что перед вызовом `#full_name` в нём не присвоили `first_name` и `last_name`.
Как говорится, garbage in — garbage out.

Однако, чем тупо «вредничать», возвращая невнятную пустоту, `#full_name` мог бы
помочь разработчику выявить эту ситуацию, чётко о ней просигналив.

Предположим, мы решили, что для корректного вычисления `#full_name` нам необходим,
как минимум, непустой `first_name`. Реализация может выглядеть так:

```ruby
class Person
  …
  def full_name
    igetset(__method__) do
      require_attr :first_name
      [first_name, last_name].compact.join(" ").strip
    end
  end
end
```

Теперь посмотрим, как это работает:

```ruby
Person.new.full_name
# RuntimeError: Attribute `first_name` must not be nil: nil
```

Вроде неплохо. Вместо пустоты мы получили исключение с указанием на причину отказа:
не присвоен `first_name`. Смущают, однако, слова про `nil`, хотя речь идёт о строковом атрибуте.
А вдруг в `first_name` пустая строка, что тогда? Пробуем:

```ruby
Person.new(first_name: "").full_name
# => ""

Person.new(first_name: " ").full_name
# => ""
```

На пустую строку наш `require_attr` пока не реагирует, хотя суть требования была в том,
чтобы `first_name` был именно *не пустой.* Чуть-чуть доработаем код:

```ruby
# Нужно для `Object#present?`.
require "active_support/core_ext/object/blank"

class Person
  …
  def full_name
    igetset(__method__) do
      require_attr :first_name, :present?
      #require_attr :first_name, :not_blank?   # Можно так.
      [first_name, last_name].compact.join(" ").strip
    end
  end
end
```

Снова пробуем вызвать:

```ruby
Person.new.full_name
# RuntimeError: Attribute `first_name` must be present: nil

Person.new(first_name: " ").full_name
# RuntimeError: Attribute `first_name` must be present: " "

Person.new(first_name: "Joe").full_name
# => "Joe"
```

Теперь и сообщение чётче, и требование выполнено.

Мы узнали, что `#require_attr` даёт возможность выполнить тривиальную валидацию
соседнего атрибута, значение которого нужно в данном вычислении.

### `#igetwrite`

Описанный в примере выше, метод `#igetset` взаимодействует с instance-переменными напрямую:
проверяет наличие, читает, записывает. В большинстве случаев этого достаточно.

Бывает, однако, что мы добавляем наш метод-вычислитель в класс, требующий записи в свои атрибуты
строго через write-аксессоры вроде `#name=`.

В таких случаях помогает `#igetwrite`.
Выполнив вычисление, он записывает значение в объект через write accessor.

## Copyright

Продукт распространяется свободно на условиях лицензии MIT.

— © 2017-2023 Алексей Фортуна
