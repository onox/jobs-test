--  Copyright (c) 2017 onox <denkpadje@gmail.com>
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

with System.Multiprocessors;

with Orka.Jobs.Workers;
with Orka.Jobs.Queues;
with Orka.Futures.Slots;

generic
   with package Slots is new Orka.Futures.Slots (<>);
   Max_Waiting_Jobs : Positive;
--   Max_Total_Jobs   : Positive;
package Orka.Jobs.Boss is

--   package Slots is new Orka.Futures.Slots (Max_Total_Jobs);

   Future_Slots  : aliased Slots.Future_Array := Slots.Make_Futures;
   Slots_Manager : aliased Slots.Manager (Future_Slots'Access);

   package Queues is new Jobs.Queues (Slots, Slots_Manager'Access);

   Queue : aliased Queues.Queue (Max_Waiting_Jobs);

   Number_Of_Workers : constant System.Multiprocessors.CPU;

   procedure Shutdown;

private

   package SM renames System.Multiprocessors;

   use type SM.CPU;

--   Number_Of_Workers : constant SM.CPU := SM.Number_Of_CPUs - 1;
   Number_Of_Workers : constant SM.CPU := 1;

   package Workers is new Orka.Jobs.Workers
     (Queues, "Worker", Queue'Unchecked_Access, Number_Of_Workers);
   --  For n logical CPU's we spawn n - 1 workers (1 CPU is dedicated
   --  to rendering)
   --  TODO Or allocate Queue with new keyword?

   procedure Shutdown renames Workers.Shutdown;

end Orka.Jobs.Boss;
