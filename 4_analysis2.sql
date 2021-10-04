-- analysis_data_base

-- Для студента с именем student_59 вывести следующую информацию по всем его попыткам:
--    информация о шаге: номер модуля, символ '.', позиция урока в модуле, символ '.', позиция шага в модуле;
--    порядковый номер попытки для каждого шага - определяется по возрастанию времени отправки попытки;
--    результат попытки;
--    время попытки (преобразованное к формату времени) - определяется как разность между временем отправки 
--         попытки и времени ее начала, в случае если попытка длилась более 1 часа, то время попытки заменить на 
--         среднее время всех попыток пользователя по всем шагам без учета тех, которые длились больше 1 часа;
--    относительное время попытки  - определяется как отношение времени попытки (с учетом замены времени попытки) 
--         к суммарному времени всех попыток  шага, округленное до двух знаков после запятой.

-- Столбцы назвать  Студент,  Шаг, Номер_попытки, Результат, Время_попытки и Относительное_время. 
-- Информацию отсортировать сначала по возрастанию id шага, а затем по возрастанию номера попытки 
-- (определяется по времени отправки попытки).

-- Важно. Все вычисления производить в секундах, округлять и переводить во временной формат только для вывода результата.

WITH 
table0 AS -- Среднее время
     (SELECT round(AVG(submission_time - attempt_time)) AS a_time
      FROM step_student JOIN student USING(student_id)
      WHERE student_name = 'student_59' AND (submission_time - attempt_time)<= (60*60)
     ),
table1 AS 
     (SELECT step_id, step_student_id, student_name AS Студент, 
             module_id, lesson_position, step_position,
             ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY  submission_time) AS Номер_попытки,
             result AS Результат,
             IF ((submission_time - attempt_time)<= (60*60), (submission_time - attempt_time), 
            (SELECT a_time FROM table0)) AS n_time -- Время попытки
      FROM step_student JOIN step USING(step_id) 
                        JOIN lesson USING(lesson_id) 
                        JOIN student USING(student_id)
      WHERE student_name = 'student_59'
     ), 
table2 AS -- Относительное время попытки
      (SELECT step_student_id, n_time / SUM(n_time) OVER (PARTITION BY step_id) AS g_time 
       FROM table1
      )
SELECT Студент, 
       CONCAT(module_id, '.', lesson_position, '.', step_position) AS Шаг, 
       Номер_попытки, 
       Результат, 
       SEC_TO_TIME(n_time) AS Время_попытки,
       ROUND(g_time*100, 2) AS Относительное_время
FROM table1
     LEFT JOIN
     table2 USING(step_student_id)
ORDER BY module_id, lesson_position, step_position, Номер_попытки;;

--------------------------------------------------------------------------
-- Выделить группы обучающихся по способу прохождения шагов:
--        I группа - это те пользователи, которые после верной попытки решения шага делают неверную 
--            (скорее всего для того, чтобы поэкспериментировать или проверить, как работают примеры);
--        II группа - это те пользователи, которые делают больше одной верной попытки для одного шага 
--            (возможно, улучшают свое решение или пробуют другой вариант);
--        III группа - это те пользователи, которые не смогли решить задание какого-то шага 
--            (у них все попытки по этому шагу - неверные).

-- Вывести группу, имя пользователя, количество шагов, которые пользователь выполнил по соответствующему способу. 
-- Столбцы назвать Группа, Студент, Количество_шагов. Отсортировать информацию по возрастанию номеров групп, 
-- потом по убыванию количества шагов и, наконец, по имени студента в алфавитном порядке.

WITH
table1 AS -- Добавлен ЛАГ
    (SELECT student_name, result, 
            LAG(result) OVER (PARTITION BY student_id, step_id 
                              ORDER BY  student_id, step_id, submission_time) AS lag_result 
     FROM step_student JOIN student USING (student_id)
    ),
table12 AS -- Отбор по условию lag_result = 'correct' AND result = 'wrong' (Группа 1)
    (SELECT 'I' AS Группа, student_name AS Студент, COUNT(*) AS Количество_шагов
     FROM table1
     WHERE lag_result = 'correct' AND result = 'wrong'
     GROUP BY student_name
     ORDER BY 3 DESC, 2
     ),
table2 AS -- Только верно решенные шаги
     (SELECT student_name, CONCAT (student_id, '.', step_id) AS student_step
      FROM step_student JOIN student USING (student_id)
      WHERE result = 'correct'
     ),
table22 AS -- Верно решенные несколько раз шаги
     (SELECT student_name, student_step, COUNT(student_step) AS Количество_верных
      FROM table2
      GROUP BY 2, 1
      HAVING COUNT(student_step) > 1
      ORDER BY 2
     ),
table23 AS -- Подсчет верно решенных шагов у студентов (Группа 2)
     (SELECT 'II' AS Группа, student_name AS Студент, COUNT(student_name) AS Количество_шагов
      FROM table22
      GROUP BY 2, 1
      ORDER BY 3 DESC, 2
     ),
table3 AS -- Все student_step c ошибками
    (SELECT DISTINCT CONCAT (student_id, '.', step_id) AS student_step
     FROM step_student JOIN student USING (student_id)
     WHERE result = 'wrong'
    ),
table31 AS
    (SELECT student_name, result, CONCAT (student_id, '.', step_id) AS student_step
     FROM step_student JOIN student USING (student_id)
    ),
table32 AS -- Все student_step c одним вариантом result (или только correct или только wrong)
    (SELECT student_step, student_name
     FROM table31
     GROUP BY student_step, student_name
     HAVING COUNT(DISTINCT result) = 1
    ),
table33 AS -- группа 3
    (SELECT 'III' AS Группа, student_name AS Студент, COUNT(student_name) AS Количество_шагов
     FROM table3 INNER JOIN table32 USING(student_step)
     GROUP BY 2, 1
     ORDER BY 3 DESC, 2
     )
SELECT * FROM table12 UNION ALL SELECT * FROM table23 UNION ALL SELECT * FROM table33;