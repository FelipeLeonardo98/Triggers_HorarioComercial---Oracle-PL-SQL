-- Triggers para manipulação de dados: Bloqueio fora de horário comercial

DECLARE
  HORA VARCHAR2(2);
  H NUMBER;
BEGIN
  H:= TO_NUMBER(TO_CHAR(SYSDATE,'HH24'));
  Dbms_Output.Put_Line(H || 'hrs - ' || TO_CHAR(SYSDATE, 'DAY'));
END;
-- -------- Verificando se  o dia da semana  é sabado ou domingo OU O horario
BEGIN
  IF(To_Char(SYSDATE, 'DAY') IN ('S�BADO', 'DOMINGO') OR
  To_Number(To_Char(SYSDATE, 'HH24')) NOT BETWEEN 8 AND 18) THEN
  Raise_Application_Error( -20001, 'Fora do horario Comercial!');
  END IF;
END;

CREATE OR REPLACE TRIGGER VALIDA_HORARIO_CURSO
BEFORE INSERT OR DELETE ON contrato
BEGIN
  IF(To_Char(SYSDATE,'D') IN (1,7) OR
  -- Esse 'D' significa DAY e o IN mostra que 1 é igual sabado e domingo igual 7
  To_Number(To_Char(SYSDATE, 'HH24'))
  -- se o horario nao estiver em hora comercial....
  NOT BETWEEN 8 AND 18) THEN
  -- gere o erro
    Raise_Application_Error(-20001, 'Fora horario comercial');
  END IF;
END;

-- testando
  INSERT INTO contrato VALUES (7665, SYSDATE, 10, 1500, NULL);
  SELECT * FROM contrato;


-- -----------------
CREATE TABLE Log
(
 USUARIO VARCHAR(30),
 HORARIO DATE,
 VALOR_ANTIGO VARCHAR(10),
 VALOR_NOVO VARCHAR(10)
);

CREATE OR REPLACE TRIGGER gera_log_alt
AFTER UPDATE OF TOTAL ON contrato
-- DEPOIS DO UPDATE SOMENTE NO CAMPO total  DA TABELA CONTRATO
DECLARE
-- variaveis
BEGIN
  INSERT INTO Log(Usuario, Horario) VALUES (USER, SYSDATE);
END;

SELECT * FROM contrato;
-- Usuario do sistema altera algo que na teoria, não poderia alterar
UPDATE contrato SET total = 5000 WHERE id_contrato = 1;

-- ent�o de acordo com o trigger gera_log_alt, pegamos quem fez isso
SELECT * FROM Log;

 ---------------------

CREATE OR REPLACE TRIGGER valida_horario_curso2
BEFORE INSERT OR UPDATE OR DELETE ON contrato
-- A trigger serve para os três comandos DML, e podemos controlar separadamente
BEGIN
  IF(To_Char(SYSDATE, 'D') IN (1,7) OR
  -- Se o dia estiver IN s�bado ou domingo  OU ....
  To_Number(To_Char(SYSDATE,'HH24')) NOT BETWEEN 8 AND 18) THEN
  -- O Hor�rio N�O ESTIVER ENTRE 8 e 17 horas.... caia na condi��o
    IF( INSERTING ) THEN
      Raise_Application_Error(-20001, 'Nao permitido inserir!');
      -- Se INSERINDO....
    ELSIF (DELETING) THEN
      Raise_Application_Error(-20002, 'Nao permitido remover');
      -- Se DELETANDO.....
    ELSIF (UPDATING ('TOTAL') ) THEN
      Raise_Application_Error(-20003, 'Nao pode alterar total');
      -- Se ATUALIZANDO o campo total
    ELSE
      Raise_Application_Error(-20004, 'Nao pode alterar');
      -- Se ATUALIZANDO outra coisa
    END IF;
  END IF;
END;

-- Testes
-- Essa trigger pode atrapalhar o teste da n�mero 2, vamos desabilitar
ALTER trigger valida_horario_curso DISABLE;

DELETE FROM contrato;
UPDATE contrato SET total = 5000 WHERE id_contrato = 1;
INSERT INTO contrato VALUES (90, SYSDATE, 10, 1500, NULL);

-- PARTE 2
ALTER TABLE Log ADD OBS VARCHAR(80);

CREATE OR REPLACE TRIGGER audita_aluno
AFTER INSERT OR DELETE OR UPDATE ON aluno
FOR EACH ROW -- executa para cada linha afetada
            -- Sem o FOR EACH ROW executa uma vez s�
BEGIN
  IF(DELETING) THEN
    INSERT INTO Log(usuario, horario, obs)
    VALUES (USER, SYSDATE, 'Deletou Registros.');
  ELSIF (INSERTING) THEN
    INSERT INTO Log(usuario, horario, obs)
    VALUES (USER, SYSDATE, 'Inseriu Registros.');
  ELSIF (UPDATING('Salario') ) THEN
    INSERT INTO Log
    VALUES (:old.nome, SYSDATE, :old.salario, :new.salario, 'Alterado Salario.');
  ELSE
    INSERT INTO Log(usuario, horario, obs)
    VALUES (USER, SYSDATE, 'Atualizacao Aluno.');
  END IF;
END;

SELECT * FROM Log;
SELECT * FROM aluno;
UPDATE aluno SET salario = 2500;


-- -------------
CREATE OR REPLACE TRIGGER gera_log_curso
BEFORE UPDATE OF valor ON curso
FOR EACH ROW
BEGIN
  INSERT INTO Log(Usuario, Horario, obs, valor_antigo,valor_novo)
  VALUES (USER, SYSDATE, 'Curso Alterado: ' || :old.nome, :old.valor, :new.valor);
END;


SELECT * FROM curso
UPDATE curso SET
valor = 3000
WHERE valor > 1500;

SELECT * FROM Log;

- -------------
-- TABELA CONTRATO
ALTER TABLE contrato ADD valor_comissao NUMERIC(8,2);

CREATE OR REPLACE TRIGGER calc_comissao
BEFORE INSERT OR UPDATE OF total ON contrato
REFERENCING OLD AS antigo
            NEW AS novo
            -- apelidando o OLD e o new
FOR EACH ROW
WHEN(novo.total >= 5000)
-- COLOCANDO CONDI��O NO TRIGGER
DECLARE
  vComissao NUMERIC(6,2) := 0.15;
  -- ADD VALOR A VARIAVEL
BEGIN
  IF(:novo.Total <= 10000) THEN
    :novo.valor_comissao := :novo.Total*(vComissao);
  ELSE
    :novo.valor_comissao := :novo.Total*(vComissao + 0.01);
  END IF;
END;

-- desabilitando a trigger pq atrapalhou no teste
ALTER TRIGGER valida_horario_curso2 DISABLE;
INSERT INTO CONTRATO(id_contrato, total) VALUES(34,6000);
INSERT INTO CONTRATO(id_contrato, total) VALUES(35,12000);
SELECT * FROM contrato;

-----------------------------------------------
-- Trigger em view
CREATE OR REPLACE VIEW vContrato_pares
AS
  SELECT id_contrato, data, id_aluno, desconto, total
  FROM contrato
  WHERE Mod(id_contrato,2) = 0;
-- -----------
SELECT * FROM vContrato_pares;

CREATE OR REPLACE TRIGGER tri_contrato_pares
INSTEAD OF INSERT OR  DELETE OR UPDATE ON vContrato_pares
DECLARE
BEGIN
  INSERT INTO Log(usuario, horario, obs)
  VALUES (USER, SYSDATE, 'DML  DA View Vcontratos_pares.');
END;

-- -------------
INSERT INTO vContrato_pares VALUES(90,SYSDATE,10,NULL,5000);
SELECT * FROM vContrato_pares;
