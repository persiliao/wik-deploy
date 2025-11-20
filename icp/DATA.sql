-- SELECT * FROM T_ICP_PPC_Scheduling WHERE SchedulePlant != RIGHT(MPRNumber, 4)
DELETE FROM T_ICP_PPC_Scheduling WHERE SchedulePlant != RIGHT(MPRNumber, 4)