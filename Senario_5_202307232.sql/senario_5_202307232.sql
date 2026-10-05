DROP TABLE IF EXISTS tool_loans;
DROP TABLE IF EXISTS tools;
CREATE TABLE tools (
    tool_id            SERIAL PRIMARY KEY,
    tool_name          VARCHAR(100) NOT NULL,
    available_quantity INT NOT NULL CHECK (available_quantity >= 0)
);
CREATE TABLE tool_loans (
    loan_id        SERIAL PRIMARY KEY,
    tool_id        INT NOT NULL REFERENCES tools(tool_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    status         VARCHAR(10) NOT NULL DEFAULT 'ISSUED'
                   CHECK (status IN ('ISSUED', 'RETURNED'))
);
INSERT INTO tools (tool_name, available_quantity) VALUES
    ('Vernier Caliper', 10),
    ('Soldering Iron', 3),
    ('Hacksaw', 0);
SELECT * FROM tools ORDER BY tool_id;








DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT tool_name, available_quantity FROM tools ORDER BY tool_id LOOP
        IF rec.available_quantity = 0 THEN
            RAISE NOTICE '% : UNAVAILABLE', rec.tool_name;
        ELSIF rec.available_quantity <= 3 THEN
            RAISE NOTICE '% : LOW on stock (%)', rec.tool_name, rec.available_quantity;
        ELSE
            RAISE NOTICE '% : readily available (%)', rec.tool_name, rec.available_quantity;
        END IF;
    END LOOP;
END $$;








DO $$
DECLARE
    n INT := 1;
BEGIN
    WHILE n <= 3 LOOP
        RAISE NOTICE 'Workshop safety reminder %', n;
        n := n + 1;
    END LOOP;
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Tool inspection number %', i;
    END LOOP;
END $$;








CREATE OR REPLACE PROCEDURE issue_tool(p_tool_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. It must be greater than zero.', p_qty;
    END IF;
    SELECT available_quantity INTO v_avail
    FROM tools WHERE tool_id = p_tool_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tool % does not exist.', p_tool_id;
    END IF;
    IF v_avail < p_qty THEN
        RAISE NOTICE 'Loan REJECTED for % : requested %, only % available.',
                     p_student, p_qty, v_avail;
        RETURN;
    END IF;
    UPDATE tools SET available_quantity = available_quantity - p_qty
    WHERE tool_id = p_tool_id;
    INSERT INTO tool_loans (tool_id, student_number, quantity)
    VALUES (p_tool_id, p_student, p_qty);
    RAISE NOTICE 'Issued % of tool % to %.', p_qty, p_tool_id, p_student;
END $$;






CALL issue_tool(1, 'S001', 4);   -- valid
CALL issue_tool(2, 'S002', 2);   -- valid
CALL issue_tool(2, 'S003', 5);   -- exceeds stock (rejected)
SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;




CREATE OR REPLACE PROCEDURE return_tool(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tool_id INT;
    v_qty     INT;
    v_status  VARCHAR(10);
BEGIN
    SELECT tool_id, quantity, status INTO v_tool_id, v_qty, v_status
    FROM tool_loans WHERE loan_id = p_loan_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist.', p_loan_id;
    END IF;
    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % was already returned. No stock added.', p_loan_id;
        RETURN;
    END IF;
    UPDATE tool_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
    UPDATE tools SET available_quantity = available_quantity + v_qty WHERE tool_id = v_tool_id;
    RAISE NOTICE 'Loan % returned. % added back to stock.', p_loan_id, v_qty;
END $$;
CALL return_tool(1);   -- restores stock
CALL return_tool(1);   -- second call: must NOT add stock again
SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;







DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT tool_name, available_quantity FROM tools
        WHERE available_quantity <= 3 ORDER BY available_quantity;
    rec RECORD;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low availability: % (% left)', rec.tool_name, rec.available_quantity;
    END LOOP;
    CLOSE cur_low;
END $$;








DO $$
BEGIN
    CALL issue_tool(1, 'S004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;



SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;
