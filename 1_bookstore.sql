-- bookstore_data_base

-- Вывести информацию о каждом заказе: его номер, кто его сформировал (фамилия пользователя) и его стоимость 
-- (сумма произведений количества заказанных книг и их цены), в отсортированном по номеру заказа виде. 
-- Последний столбец назвать Стоимость.

SELECT buy_id, name_client, SUM(buy_book.amount * price)  AS Стоимость
FROM buy_book 
    JOIN book USING (book_id)
    JOIN buy USING (buy_id)
    JOIN client USING (client_id)
GROUP BY buy_id
ORDER BY buy_id;

--------------------------------------------------------------------------
-- Для книг, которые уже есть на складе (в таблице book), но по другой цене, чем в поставке (supply),  
-- необходимо в таблице book увеличить количество на значение, указанное в поставке,  и пересчитать цену. 
-- А в таблице  supply обнулить количество этих книг. Формула для пересчета цены:
    -- price=(p1∗k1+p2∗k2)/(k1+k2) ​где 
    -- p1, p2 - цена книги в таблицах book и supply
    -- k1, k2 - количество книг в таблицах book и supply.

UPDATE book 
     INNER JOIN author ON author.author_id = book.author_id
     INNER JOIN supply ON book.title = supply.title 
                         and supply.author = author.name_author
SET book.amount = book.amount + supply.amount,
    supply.amount = 0,
    book.price = (book.price * book.amount + supply.price * supply.amount)/(book.amount + supply.amount)
WHERE book.price <> supply.price;

--------------------------------------------------------------------------
-- Удалить всех авторов, которые пишут в жанре "Поэзия". 
-- Из таблицы book удалить все книги этих авторов. 
-- В запросе для отбора авторов использовать полное название жанра, а не его id.

DELETE FROM author
USING 
    author 
    INNER JOIN book ON author.author_id = book.author_id
WHERE book.genre_id IN (
       SELECT genre_id 
       FROM genre 
       WHERE name_genre = 'Поэзия'
      );
--------------------------------------------------------------------------
-- Сравнить ежемесячную выручку от продажи книг за текущий и предыдущий годы. 
-- Для этого вывести год, месяц, сумму выручки в отсортированном сначала по 
-- возрастанию месяцев, затем по возрастанию лет виде. Название столбцов: Год, Месяц, Сумма.

SELECT YEAR(date_payment) AS 'Год', MONTHNAME(date_payment) AS 'Месяц', SUM(amount * price) AS 'Сумма'
FROM 
    buy_archive
GROUP BY Год, Месяц
UNION ALL
SELECT YEAR(date_step_end) AS 'Год', MONTHNAME(date_step_end) AS 'Месяц', SUM(buy_book.amount * price) AS 'Сумма'
FROM 
    book 
    INNER JOIN buy_book USING(book_id)
    INNER JOIN buy USING(buy_id) 
    INNER JOIN buy_step USING(buy_id)
    INNER JOIN step USING(step_id)                  
WHERE  date_step_end IS NOT Null and name_step = "Оплата"
GROUP BY Год, Месяц
ORDER BY Месяц, Год;