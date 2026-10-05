DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;
CREATE TABLE hostel_rooms (
    room_id          SERIAL PRIMARY KEY,
    room_name        VARCHAR(20) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);
CREATE TABLE allocations (
    allocation_id  SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    room_id        INT NOT NULL REFERENCES hostel_rooms(room_id),
    status         VARCHAR(12) NOT NULL DEFAULT 'ALLOCATED'
                   CHECK (status IN ('ALLOCATED', 'COMPLETE'))
);
INSERT INTO hostel_rooms (room_name, available_spaces) VALUES
    ('Room A101', 3),
    ('Room B202', 1),
    ('Room C303', 0);
SELECT * FROM hostel_rooms ORDER BY room_id;





DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT room_name, available_spaces FROM hostel_rooms ORDER BY room_id LOOP
        IF rec.available_spaces = 0 THEN
            RAISE NOTICE '% : FULL', rec.room_name;
        ELSIF rec.available_spaces = 1 THEN
            RAISE NOTICE '% : has ONE space left', rec.room_name;
        ELSE
            RAISE NOTICE '% : has several spaces (%)', rec.room_name, rec.available_spaces;
        END IF;
    END LOOP;
END $$;







DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', d;
        d := d + 1;
    END LOOP;
    FOR r IN 1..3 LOOP
        RAISE NOTICE 'Room check number %', r;
    END LOOP;
END $$;	












CREATE OR REPLACE PROCEDURE allocate_room(p_student VARCHAR, p_room_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student IS NULL OR TRIM(p_student) = '' THEN
        RAISE EXCEPTION 'Invalid input: student number cannot be blank.';
    END IF;
    SELECT available_spaces INTO v_spaces
    FROM hostel_rooms WHERE room_id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room % does not exist.', p_room_id;
    END IF;
    IF v_spaces < 1 THEN
        RAISE NOTICE 'Allocation REJECTED for % : room % is full.', p_student, p_room_id;
        RETURN;
    END IF;
    UPDATE hostel_rooms SET available_spaces = available_spaces - 1
    WHERE room_id = p_room_id;
    INSERT INTO allocations (student_number, room_id) VALUES (TRIM(p_student), p_room_id);
    RAISE NOTICE 'Student % allocated to room %.', p_student, p_room_id;
END $$;






CALL allocate_room('S001', 1);   -- valid
CALL allocate_room('S002', 2);   -- valid (room B202 becomes full)
CALL allocate_room('S003', 3);   -- room C303 is full (rejected)
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;







CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
    v_status  VARCHAR(12);
BEGIN
    SELECT room_id, status INTO v_room_id, v_status
    FROM allocations WHERE allocation_id = p_allocation_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Allocation % does not exist.', p_allocation_id;
    END IF;
    IF v_status = 'COMPLETE' THEN
        RAISE NOTICE 'Allocation % is already complete. No space freed.', p_allocation_id;
        RETURN;
    END IF;
    UPDATE allocations SET status = 'COMPLETE' WHERE allocation_id = p_allocation_id;
    UPDATE hostel_rooms SET available_spaces = available_spaces + 1 WHERE room_id = v_room_id;
    RAISE NOTICE 'Allocation % checked out. One space freed in room %.', p_allocation_id, v_room_id;
END $$;
CALL check_out(2);   -- frees one space
CALL check_out(2);   -- second call: must NOT free another space
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;








DO $$
DECLARE
    cur_rooms CURSOR FOR
        SELECT room_name, available_spaces FROM hostel_rooms
        WHERE available_spaces <= 1 ORDER BY room_id;
    rec RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full or nearly full: % (% space(s) left)', rec.room_name, rec.available_spaces;
    END LOOP;
    CLOSE cur_rooms;
END $$;








DO $$
BEGIN
    CALL allocate_room('   ', 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;









SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id
