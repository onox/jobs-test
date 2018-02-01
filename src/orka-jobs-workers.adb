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

with System.Multiprocessors.Dispatching_Domains;

with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Tags;
with Ada.Text_IO;

with Orka.Containers.Bounded_Vectors;
with Orka.Futures;
with Orka.OS;

package body Orka.Jobs.Workers is

   function Get_Root_Dependent (Element : Job_Ptr) return Job_Ptr is
      Result : Job_Ptr := Element;
   begin
      while Result.Dependent /= Null_Job loop
         Result := Result.Dependent;
      end loop;
      return Result;
   end Get_Root_Dependent;

   task body Worker_Task is
      package SM renames System.Multiprocessors;
      package SF renames Ada.Strings.Fixed;

      use type SM.CPU;
      use type Ada.Real_Time.Time;

      ID   : constant String := Positive'Image (Data.ID);
      Name : constant String := Prefix & " #" & SF.Trim (ID, Ada.Strings.Left);

      Pair : Queues.Pair;
      Stop : Boolean := False;

      Null_Pair : constant Queues.Pair := Queues.Get_Null_Pair;

      package Vectors is new Orka.Containers.Bounded_Vectors (Job_Ptr, Get_Null_Job);

      T0, T1, T2 : Ada.Real_Time.Time;
      Ref_C : Natural;
      use Ada.Text_IO;
   begin
      --  Set the CPU affinity of the task to its corresponding CPU core
      SM.Dispatching_Domains.Set_CPU (SM.CPU (Data.ID) + 1);
      Orka.OS.Set_Task_Name (Name);

--      delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (10);
      loop
         T0 := Ada.Real_Time.Clock;
         Put_Line (Name & " dequeueing...");
         Queue.Dequeue (Pair, Stop, Ref_C);
--         delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (10);
         Put_Line (Name & " dequeued " & Ref_C'Image);
         exit when Stop;
         Put_Line (Name & " starting -- refs: " & Pair.Future.References'Image);

         declare
            Job    : Job_Ptr renames Pair.Job;
--            Future : Futures.Future_Access renames Pair.Future.Get;

            Job_Tag : String renames Ada.Tags.Expanded_Name (Job'Tag);

            Jobs : Vectors.Vector (Capacity => 1000);
            --  Large capacity just for debuggging purposes

            --  If Job is the current job and Job.Dependent is the successor, that is:
            --
            --    Job --> Job.Dependent
            --
            --  Then we want to insert a new job graph between these 2 jobs. Vector Jobs
            --  contains the leaves of this new graph.
            procedure Enqueue (Element : Job_Ptr) is
            begin
               Jobs.Append (Element);
            end Enqueue;

            --  In Set_Root_Dependent we look up the roots of the leaves (the current
            --  job might have created more than 1 job graph) and we connect these
            --  roots to Job.Dependent. If Job has no Job.Dependent, then we create
            --  an Empty_Job instead that acts as the final job.
            procedure Set_Root_Dependent (Last_Job : Job_Ptr) is
               Root_Dependents : Vectors.Vector (Capacity => Jobs.Length);

               procedure Set_Dependencies (Elements : Vectors.Element_Array) is
               begin
                  Last_Job.Set_Dependencies (Dependency_Array (Elements));
                  Put_Line (Name & " set deps: " & Root_Dependents.Length'Image);
               end Set_Dependencies;
            begin
               for Job of Jobs loop
                  declare
                     Root : constant Job_Ptr := Get_Root_Dependent (Job);
                  begin
                     --  Add if Root is not already in Root_Dependents
                     if not (for some Dependent of Root_Dependents => Root = Dependent) then
                        Root_Dependents.Append (Root);
                     end if;
                  end;
               end loop;

               Root_Dependents.Query (Set_Dependencies'Access);
            end Set_Root_Dependent;
         begin
            T1 := Ada.Real_Time.Clock;

--            Future.Set_Status (Futures.Running);
            Pair.Future.Get.all.Set_Status (Futures.Running);
            begin
               Job.Execute (Enqueue'Access);
            exception
               when others =>
--                  Future.Set_Status (Futures.Failed);
                  Pair.Future.Get.all.Set_Status (Futures.Failed);
                  raise;
            end;

            T2 := Ada.Real_Time.Clock;

            declare
               Waiting_Time : constant Duration := 1e3 * Ada.Real_Time.To_Duration (T1 - T0);
               Time : constant Duration := 1e3 * Ada.Real_Time.To_Duration (T2 - T1);
            begin
               Put_Line (Name & " (blocked" & Duration'Image (Waiting_Time) & " ms) executed job " & Job_Tag & " in" & Duration'Image (Time) & " ms -- refs: " & Pair.Future.References'Image);
            end;

            if Job.Dependent /= Null_Job then
               --  Make the root dependents of the jobs in Jobs
               --  dependencies of Job.Dependent
               Put_Line (Name & " : " & Job_Tag & " has dependent");
               if not Jobs.Empty then
                  Put_Line (Name & " : " & Job_Tag & " has created new jobs A");
                  Set_Root_Dependent (Job.Dependent);
               end if;

               --  If another job depends on this job, decrement its dependencies counter
               --  and if it has reached zero then it can be scheduled
               if Job.Dependent.Decrement_Dependencies then
                  declare
                     Refs_A, Refs_B : Natural;
                  begin
                     Queue.Enqueue (Job.Dependent, Pair.Future, Refs_A, Refs_B);
                     Put_Line (Name & " enqueued dependent Refs_A: " & Refs_A'Image & " Refs_B: " & Refs_B'Image);
                  end;
               end if;
            elsif Jobs.Empty then
               Put_Line (Name & " : " & Job_Tag & " is done");
--               Future.Set_Status (Futures.Done);
               Pair.Future.Get.all.Set_Status (Futures.Done);
            else
               Put_Line (Name & " : " & Job_Tag & " has created new jobs B (" & Jobs.Length'Image & ") refs:" & Pair.Future.References'Image);
               --  If the job has enqueued new jobs, we need to create an
               --  empty job which has the root dependents of these new jobs
               --  as dependencies. This is so that the empty job will be the
               --  last job that is given Pair.Future
               Set_Root_Dependent (Create_Empty_Job);
            end if;

            if not Jobs.Empty then
               declare
                  Refs_A, Refs_B : Natural;
               begin
                  Put_Line (Name & " enqueueing jobs... refs: " & Pair.Future.References'Image);
                  for Job of Jobs loop
                     Queue.Enqueue (Job, Pair.Future, Refs_A, Refs_B);
                     Put_Line (Name & " enqueued job Refs_A: " & Refs_A'Image & " Refs_B: " & Refs_B'Image);
                  end loop;
                  Put_Line (Name & " enqueueing jobs... refs: " & Pair.Future.References'Image);
               end;
            end if;

            Free (Job);
         end;
         Put_Line (Name & " finished -- refs: " & Pair.Future.References'Image);

         --  Finalize the smart pointer (Pair.Future) to reduce the number
         --  of references to the Future object
         Pair := Null_Pair;
      end loop;
      Put_Line (Name & " terminated");
   exception
      when Error : others =>
         Put_Line (Name & " : " & Ada.Tags.Expanded_Name (Job'Tag) & " : " & Ada.Exceptions.Exception_Information (Error));
   end Worker_Task;

   function Make_Workers return Worker_Array is
   begin
      return Result : Worker_Array (1 .. Positive (Count)) do
         for Index in Result'Range loop
            Result (Index).ID := Index;
         end loop;
      end return;
   end Make_Workers;

   procedure Shutdown is
   begin
      Queue.Shutdown;
   end Shutdown;

end Orka.Jobs.Workers;
