FasdUAS 1.101.10   ��   ��    k             l     ��  ��      BringAppToFront.scpt     � 	 	 *   B r i n g A p p T o F r o n t . s c p t   
  
 l     ��  ��    C = Syntax:  osascript BringAppToFront.scpt "%application_path%"     �   z   S y n t a x :     o s a s c r i p t   B r i n g A p p T o F r o n t . s c p t   " % a p p l i c a t i o n _ p a t h % "      l     ��  ��    Q K Example:  osascript BringAppToFront.scpt "/Applications/Google Chrome.app"     �   �   E x a m p l e :     o s a s c r i p t   B r i n g A p p T o F r o n t . s c p t   " / A p p l i c a t i o n s / G o o g l e   C h r o m e . a p p "      l     ��������  ��  ��        l     ��  ��    I C This script will bring the indicated application to the foreground     �   �   T h i s   s c r i p t   w i l l   b r i n g   t h e   i n d i c a t e d   a p p l i c a t i o n   t o   t h e   f o r e g r o u n d      l     ��������  ��  ��        l     ��   ��     
!/bin/bash      � ! !  ! / b i n / b a s h   "�� " i      # $ # I     �� %��
�� .aevtoappnull  �   � **** % o      ���� 0 argv  ��   $ k     : & &  ' ( ' r      ) * ) c      + , + l     -���� - n      . / . 4    �� 0
�� 
cobj 0 m    ����  / o     ���� 0 argv  ��  ��   , m    ��
�� 
TEXT * o      ���� 0 apppath   (  1 2 1 r   	  3 4 3 m   	 
��
�� boovfals 4 o      ���� 0 	doesexist 	doesExist 2  5 6 5 Q    * 7 8 9 7 k     : :  ; < ; O    = > = e     ? ? 5    �� @��
�� 
appf @ m     A A � B B D n e t . p r o m i n i c . M o o n s h i n e S D K I n s t a l l e r
�� kfrmID   > m     C C�                                                                                  MACS  alis    t  Macintosh HD               �(��H+  �>
Finder.app                                                     �����O        ����  	                CoreServices    �(��      ��o�    �>�=�<  6Macintosh HD:System: Library: CoreServices: Finder.app   
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��   <  D�� D r     E F E m    ��
�� boovtrue F o      ���� 0 	doesexist 	doesExist��   8 R      ������
�� .ascrerr ****      � ****��  ��   9 r   ' * G H G m   ' (��
�� boovfals H o      ���� 0 	doesexist 	doesExist 6  I J I l  + +��������  ��  ��   J  K�� K Z   + : L M���� L =  + . N O N o   + ,���� 0 	doesexist 	doesExist O m   , -��
�� boovtrue M I  1 6�� P��
�� .sysoexecTEXT���     TEXT P m   1 2 Q Q � R R X o p e n   - b   " n e t . p r o m i n i c . M o o n s h i n e S D K I n s t a l l e r "��  ��  ��  ��  ��       �� S T��   S ��
�� .aevtoappnull  �   � **** T �� $���� U V��
�� .aevtoappnull  �   � ****�� 0 argv  ��   U ���� 0 argv   V �������� C�� A������ Q��
�� 
cobj
�� 
TEXT�� 0 apppath  �� 0 	doesexist 	doesExist
�� 
appf
�� kfrmID  ��  ��  
�� .sysoexecTEXT���     TEXT�� ;��k/�&E�OfE�O � *���0EUOeE�W 
X  	fE�O�e  
�j Y hascr  ��ޭ