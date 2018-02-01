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

with Ada.Text_IO;

package body Orka.Jobs.Queues is

   procedure Free_Future (Value : in out Futures.Future_Access) is
   begin
      Ada.Text_IO.Put_Line ("Releasing slot...");
      Manager.Release (Slots.Future_Object_Access (Value));
      Ada.Text_IO.Put_Line ("Released slot!");
   end Free_Future;

   protected body Queue is

      function Can_Schedule_Job (P : Priority) return Boolean is
      begin
         case P is
            when High =>
               return not Priority_High.Full;
            when Normal =>
               return not Priority_Normal.Full;
         end case;
      end Can_Schedule_Job;

      function Has_Jobs return Boolean is
        (not Priority_High.Empty or else not Priority_Normal.Empty);

      entry Enqueue
        (Element : Job_Ptr;
         Future  : in out Futures.Pointers.Pointer;
         Refs_A, Refs_B : out Natural) when True is
      begin
         --  Prioritize jobs that have no dependencies themselves but
         --  are a dependency of some other job.
         if Element.Dependent /= Null_Job then
            requeue Enqueue_Job (High);
         else
            requeue Enqueue_Job (Normal);
         end if;
      end Enqueue;

      entry Enqueue_Job (for P in Priority)
        (Element : Job_Ptr;
         Future  : in out Futures.Pointers.Pointer;
         Refs_A, Refs_B : out Natural) when Can_Schedule_Job (P) is
      begin
         if Future.Is_Null then
            declare
               Slot : Slots.Future_Object_Access;
            begin
               Manager.Acquire (Slot);
               -- TODO potentially blocking operation
               Future.Set (Futures.Future_Access (Slot), Free_Future'Access);
               --  TODO Add to the barrier "and Manager.Free_Slot_Available"?
               --  TODO and put a select-else around Acquire?
            end;
         end if;
         Refs_A := Future.References;

         case P is
            when High =>
               Priority_High.Add_Last ((Job => Element, Future => Future));
            when Normal =>
               Priority_Normal.Add_Last ((Job => Element, Future => Future));
         end case;
         Refs_B := Future.References;
      end Enqueue_Job;

      entry Dequeue
        (Element : out Pair;
         Stop    : out Boolean;
         Ref_C : out Natural) when Should_Stop or else Has_Jobs is
      begin
         Stop := Should_Stop;
         if Should_Stop then
            Ref_C := 0;
            return;
         end if;

         --  Prioritize jobs that have no dependencies themselves but
         --  are a dependency of some other job.
         if not Priority_High.Empty then
            Element := Priority_High.Remove_First;
         elsif not Priority_Normal.Empty then
            Element := Priority_Normal.Remove_First;
         end if;
         Ref_C := Element.Future.References;
      end Dequeue;

      procedure Shutdown is
      begin
         Should_Stop := True;
      end Shutdown;

      function Length (P : Priority) return Natural is
      begin
         case P is
            when High =>
               return Priority_High.Length;
            when Normal =>
               return Priority_Normal.Length;
         end case;
      end Length;
   end Queue;

end Orka.Jobs.Queues;
