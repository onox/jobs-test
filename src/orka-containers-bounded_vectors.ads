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

private with Ada.Iterator_Interfaces;
private with Ada.Finalization;

generic
   type Element_Type is private;
   with function Null_Element return Element_Type;
package Orka.Containers.Bounded_Vectors is
   pragma Preelaborate;

   type Cursor is private;

   No_Element : constant Cursor;

   type Vector (Capacity : Positive) is tagged private
     with Constant_Indexing => Element;

   procedure Append (Container : in out Vector; Element : Element_Type)
     with Pre  => Container.Length < Container.Capacity,
          Post => Container.Length = Container'Old.Length + 1;
   --  Add the element to the end of the vector

   type Element_Array is array (Positive range <>) of Element_Type;

   procedure Query
     (Container : Vector;
      Process   : not null access procedure (Elements : Element_Array));

   function Element (Container : Vector; Index : Positive) return Element_Type;

   function Element
     (Container : aliased Vector;
      Position  : Cursor) return Element_Type;

   function Length (Container : Vector) return Natural;

   function Empty (Container : Vector) return Boolean;

   function Full (Container : Vector) return Boolean;

private

   function Has_Element (Position : Cursor) return Boolean is
     (Position /= No_Element);

   package Vector_Iterator_Interfaces is new Ada.Iterator_Interfaces (Cursor, Has_Element);

   function Iterate (Container : Vector)
     return Vector_Iterator_Interfaces.Reversible_Iterator'Class;

   type Vector (Capacity : Positive) is tagged record
      Elements : Element_Array (1 .. Capacity) := (others => Null_Element);
      Length   : Natural  := 0;
   end record
     with Default_Iterator  => Iterate,
          Iterator_Element  => Element_Type;

   -----------------------------------------------------------------------------

   type Vector_Access is access constant Vector;

   type Cursor is record
      Object : Vector_Access;
      Index  : Natural;
   end record;

   No_Element : constant Cursor := Cursor'(null, 0);

   -----------------------------------------------------------------------------

   use Ada.Finalization;

   type Iterator is new Limited_Controlled and
     Vector_Iterator_Interfaces.Reversible_Iterator with
   record
      Container : Vector_Access;
   end record;

   overriding function First (Object : Iterator) return Cursor;
   overriding function Last  (Object : Iterator) return Cursor;

   overriding function Next
     (Object   : Iterator;
      Position : Cursor) return Cursor;

   overriding function Previous
     (Object   : Iterator;
      Position : Cursor) return Cursor;

end Orka.Containers.Bounded_Vectors;
