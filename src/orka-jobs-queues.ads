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

with Orka.Containers.Ring_Buffers;
with Orka.Futures.Slots;

generic
   with package Slots is new Orka.Futures.Slots (<>);
   Manager : not null access Slots.Manager;
package Orka.Jobs.Queues is
--   pragma Preelaborate;

   type Priority is (High, Normal);

   type Pair is record
      Job    : Job_Ptr := Null_Job;
      Future : Futures.Pointers.Pointer;
   end record;

   function Get_Null_Pair return Pair is (others => <>);

   package Buffers is new Orka.Containers.Ring_Buffers (Pair, Get_Null_Pair);

   protected type Queue (Capacity : Positive) is
      entry Enqueue (Element : Job_Ptr; Future : in out Futures.Pointers.Pointer; Refs_A, Refs_B : out Natural);
      --  Refs_A and Refs_B are for debugging purposes
      --  TODO Pre => not Element.Has_Dependencies
      --         and then Element.all not in Parallel_Job'Class
      --         and then Element /= Null_Job

      entry Dequeue (Element : out Pair; Stop : out Boolean; Ref_C : out Natural)
        with Post => not Element.Job.Has_Dependencies;
      --  Ref_C is for debugging purposes

      procedure Shutdown;

      function Length (P : Priority) return Natural;
   private
      entry Enqueue_Job (Priority)
        (Element : Job_Ptr;
      Future  : in out Futures.Pointers.Pointer; Refs_A, Refs_B : out Natural);
      --  Refs_A and Refs_B are for debugging purposes

      Priority_High, Priority_Normal : Buffers.Buffer (Capacity);
      Should_Stop : Boolean := False;
   end Queue;

   type Queue_Ptr is not null access all Queue;

end Orka.Jobs.Queues;
