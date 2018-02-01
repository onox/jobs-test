--  Copyright (c) 2018 onox <denkpadje@gmail.com>
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

with Ada.Real_Time;
with Ada.Text_IO;

with Orka.Futures;
with Orka.Jobs;
with Orka_Test.Package_9_Jobs;

procedure Orka_Test.Test_9_Jobs is

   Job_0 : constant Orka.Jobs.Job_Ptr := new Package_9_Jobs.Test_Sequential_Job'
     (Orka.Jobs.Abstract_Job with ID => 0);
   Job_1 : constant Orka.Jobs.Job_Ptr := new Package_9_Jobs.Test_Sequential_Job'
     (Orka.Jobs.Abstract_Job with ID => 1);
--   Job_2 : constant Orka.Jobs.Job_Ptr := new Package_9_Jobs.Test_Sequential_Job'
--     (Orka.Jobs.Abstract_Job with ID => 2);

   Job_3 : constant Orka.Jobs.Parallel_Job_Ptr := new Package_9_Jobs.Test_Parallel_Job;
   Job_4 : constant Orka.Jobs.Job_Ptr := Orka.Jobs.Parallelize (Job_3, 2400, 3);

   Future : Orka.Futures.Pointers.Pointer;
   Refs_A, Refs_B : Natural;
   Status : Orka.Futures.Status;
   use type Ada.Real_Time.Time;
   T1, T2 : Ada.Real_Time.Time;

   use Ada.Text_IO;
begin
   --  Graph: Job_0 --> Job_1 --> Job_4 (4 slices) --> Job_2
   Job_1.Set_Dependencies ((1 => Job_0));
   Job_4.Set_Dependencies ((1 => Job_1));
--   Job_2.Set_Dependencies ((1 => Job_4));

   Package_9_Jobs.Boss.Queue.Enqueue (Job_0, Future, Refs_A, Refs_B);
   Put_Line ("references A: " & Future.References'Image);
   Put_Line ("Refs_A: " & Refs_A'Image);
   Put_Line ("Refs_B: " & Refs_B'Image);
   delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (1000);
   T1 := Ada.Real_Time.Clock;

   select
      Future.Get.all.Wait_Until_Done (Status);
      T2 := Ada.Real_Time.Clock;
      Put_Line ("     Jobs done: " & Status'Image & " " & Future.References'Image);
      Put_Line ("     Time: " & Duration'Image (1e3 * Ada.Real_Time.To_Duration (T2 - T1)));
   or
      delay until Ada.Real_Time.Clock + Ada.Real_Time.Seconds (10);
      Put_Line ("     Jobs not done: " & Future.Get.all.Current_Status'Image);
   end select;
   Put_Line ("references B (expects >= 1): " & Future.References'Image);
   Put_Line ("shutting down...");
   Package_9_Jobs.Boss.Shutdown;
   delay until Ada.Real_Time.Clock + Ada.Real_Time.Seconds (2);
   Put_Line ("shutting down?");
   Put_Line ("references C (expects 1): " & Future.References'Image);
   Put_Line ("Queue high (expects 0): " & Package_9_Jobs.Boss.Queue.Length (Package_9_Jobs.Boss.Queues.High)'Image);
   Put_Line ("Queue normal (expects 0): " & Package_9_Jobs.Boss.Queue.Length (Package_9_Jobs.Boss.Queues.Normal)'Image);
   Put_Line ("Slots acquired (expects 1): " & Natural'Image (Package_9_Jobs.Boss.Slots_Manager.Acquired_Length));

   --  Note: Change Number_Of_Workers in Orka.Jobs.Boss:47 to 1 (OK) or > 1 (buggy)
   Put_Line ("Note: If references C = 1 then we should now see the slot being released...");
   Put_Line ("Note: Change Number_Of_Workers in Orka.Jobs.Boss to 2 instead of 1 to see that");
   Put_Line ("      usually references C > 1");
end Orka_Test.Test_9_Jobs;
