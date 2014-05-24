# Autore: Renata Januškeviča
# 23.05.2014
# Lai palaistu skriptu, ir nepieciešams ielādēt skriptu gdb ar "source <script.gdb>"" komandu un izsaukt lietotāja
# definēto komandu analyze ar 2 argumentiem:
# $arg0: galvenās arēnas adrese, kuru iespējams iegūt ar komandu "p &main_arena"
# $arg1: skaitlis, kurš norāda gabalu skaitu, kuros tiks sadalīta kaudze
# Piemēram: "analyze 0x845e000 5"

# $arg0: galvenās arēnas adrese
# $arg1: bin saraksta numurs
# komanda iet cauri visiem gabaliem sarakstā
define free_chunk_list
	# bin saraksta sākuma adrese
	set $start_bin = (long *) ($arg0 + 56 + $arg1 * 8)
	# molloc() funkcija atgriež šo adresi programmai
	set $free_chunk = (long *) ($start_bin[1] + 8)
	# atmiņas gabalu daudzums sarakstā
	set $chunk_count = 0
	# maksimāls gabala izmērs
	set $chunk_max_size = 0
	# gabalu kopējais skaits sarakstā
	set $total_size = 0

	while ($free_chunk != $start_bin)
		# pēdējie 3 biti netiek izmantoti izmēra glabāšanai
        # nepieciešams atņemt -4, jo pirms katra atbrīvotā gabala atrodas iedalītais, kurš aizņem atbrīvota gabala pirmos 4 baitus
		set $chunk_size = ($free_chunk[-1] & ~7)  - 4

		if ($chunk_count == 0)
			set $chunk_max_size = $chunk_size 
			set $chunk_min_size = $chunk_size
		else
			if ($chunk_min_size > $chunk_size)
				set $chunk_min_size = $chunk_size
			end
			if ($chunk_max_size < $chunk_size)
				set $chunk_max_size = $chunk_size
			end
		end

		set $chunk_count = $chunk_count + 1
		set $total_size = $total_size + $chunk_size
		set $free_chunk = (long *) ($free_chunk[1] + 8)
	end

	# dati par katru sarakstu
	if ($chunk_count == 0)
 		printf "Bin numurs %i: tukšs\n", $arg1 + 1
 	else
 		printf "Bin numurs %i: %i gabals(-li) (%i - %i baiti), kopumā = %i baiti\n", $arg1 + 1, $chunk_count, $chunk_min_size,     $chunk_max_size, $total_size
 	end
end

# $arg0: galvenās arēnas adrese
# komanda druka kopējo statistiku
define print_stat
	set $system_mem = (long *) ($arg0 + 1096)
	set $top_size_address = (long *) ($top_address[0] + 4)

	# Top gabalam vienmēr ir izmantots iepriekšējais atmiņas gabals un P zīme ir vienmēr uzlikta
	set $top_chunk_size = $top_size_address[0] - 1
	set $alloc_memory = $system_mem[0] - $free_in_arena - $top_chunk_size
	set $used_and_freed = $system_mem[0] - $top_chunk_size
	
	printf "Atbrīvoto gabalu skaits arēnā: %i,\n", $count_in_arena
	printf "Lielākā gabala izmērs: %i baiti (%i KiB, %i MiB),\n", $biggest_free_size, $biggest_free_size/1024, $biggest_free_size/1024/1024
	printf "Kaudzes segmenta izmērs: %i baiti (%i KiB, %i MiB),\n", $system_mem[0], $system_mem[0]/1024, $system_mem[0]/1024/1024
	printf "Kopējais programmai iedalītais atmiņas daudzums: %i baiti (%i KiB, %i MiB),\n", $alloc_memory, $alloc_memory/1024, $alloc_memory/1024/1024
	printf "Atbrīvotā atmiņa bin sarakstos: %i baiti (%i KiB, %i MiB),\n", $free_in_arena, $free_in_arena/1024, $free_in_arena/1024/1024
	printf "Top gabala izmērs: %i baiti (%i KiB, %i MiB),\n", $top_chunk_size, $top_chunk_size/1024, $top_chunk_size/1024/1024
end

# $arg0: galvenās arēnas adrese
# $arg1: kaudzes sadalījums apgabalos
# komanda izvada fragmentāciju, fragmentācija tiek izrēķināta sekojoši: (atbrīvoto gabalu izmērs)/(atbrīvoto un iedalīto gabalu izmērs)*100
define check_fragm
	set $fract_size = $used_and_freed/$arg1
	set $heap_pointer =  (long *) ($top_address[0] - $system_mem[0] + $top_chunk_size)
	set $chunk_size = 0

	while ($heap_pointer != $top_address[0]) 
		set $free_size = 0
		set $alloc_size = 0

		set $fract_fin = $heap_pointer + $fract_size/4
		set $fract_start = $heap_pointer
		while (($heap_pointer < $fract_fin) && ($heap_pointer != $top_address[0]))
			set $prev_in_use = ($heap_pointer[1] & 1)
			if ($prev_in_use == 1) 
				set $alloc_size = $alloc_size + $chunk_size
                set $chunk_size = ($heap_pointer[1] & ~7) - 4
			else
				set $free_size = $free_size + $chunk_size
                set $chunk_size = ($heap_pointer[1] & ~7)
			end
			set $heap_pointer = $heap_pointer + (($heap_pointer[1] & ~7)/4)
		end

		set $fragmentation = ((double) $free_size/($alloc_size + $free_size)) * 100
		printf "Atbrīvoto un iedalīto gabalu attiecībā apgabalā 0x%x - 0x%x: %i%%\n", $fract_start, $fract_fin, $fragmentation
	end
end

# $arg0: galvenās arēnas adrese
# $arg1: kaudzes sadalījums apgabalos
define analyze
	set $free_in_arena = 0
	set $bin_number = 0
	set $biggest_free_size = 0
	set $count_in_arena = 0
	set $top_address = (long *) ($arg0 + 48)

	if ($top_address[0] != 0)
		# Lai savāktu statistiku ejam cauri visiem 128 bin sarakstiem
		while ($bin_number < 127)
			free_chunk_list $arg0 $bin_number
			if ($biggest_free_size < $chunk_max_size)
				set $biggest_free_size = $chunk_max_size
			end
			set $bin_number = $bin_number + 1
			set $free_in_arena = $free_in_arena + $total_size
			set $count_in_arena = $count_in_arena + $chunk_count
		end
	
		print_stat $arg0
		if ($arg1 != 0)
			check_fragm $arg0 $arg1
		end
	else
		printf "Atmiņa programmā netiek dinamiski iedalīta."
	end
end