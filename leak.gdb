#***************************************************#
# Autore: Renata Januškeviča
# 29.05.2014
# Lai palaistu skriptu, ir nepieciešams:
# 1) ielādēt skriptu gdb atkļūdotājā ar "source <script.gdb>" komandu,
# 2) izsaukt lietotāja definēto komandu analyze ar 1 argumentu,
# $arg0: galvenās arēnas adrese, kuru iespējams iegūt ar komandas "p &main_arena" palīdzību;
# Pirms sāks skripta izpildi ir nepieciešams novietot atmiņas izmeti darbā mapē un jāpaliecinās, ka atmiņas izmetes nosaukums ir core
# Piemēram: "analyze 0x845e000"
#***************************************************#

# $arg0: norāde, kuru nepieciešams atrast procesa adrešu telpā
# 
define reverse
	set $addr = (long) $arg0
	set $addr_1 = ($addr & 0x000000ff) << 24
	set $addr_2 = ($addr & 0x0000ff00) << 8
	set $addr_3 = ($addr & 0x00ff0000) >> 8	
	set $addr_4 = ($addr & 0xff000000) >> 24
	set $malloc_pointer = $addr_1 + $addr_2 + $addr_3 + $addr_4
end

# $arg0: norāde, kuru nepieciešams atrast procesa adrešu telpā
# komanda palīdz saskaitīt priekšējās nulles
define count_zero
	set $zero = 0
	set $tmp = 0x0f000000
	while ($tmp > $arg0)
		set $zero = $zero + 1
		set $tmp = $tmp >> 4
	end
end

# $arg0: galvenās arēnas adrese
# komanda apstaiga kaudzi, saskaita gabalu skaitu bez norādēm un  izdruka rezultātu
define get_alloc_chunk
	# mainīgie, kas palīdz iegūt norādi uz kaudzi
	set $top_address = (long *) ($arg0 + 48)
	set $system_mem = (long *) ($arg0 + 1096)
	set $top_size_address = (long *) ($top_address[0] + 4)
	set $top_chunk_size = $top_size_address[0] & ~7
	set $heap_pointer =  (long *) ($top_address[0] - $system_mem[0] + $top_chunk_size)
	# $malloc_pointer ir norāde, kura tiek atgriezta programmai
	set $malloc_pointer = 0
 	# $ skaitītājs atmiņas gabaliem bez norādēm
	set $unref = 0

	while ($heap_pointer != $top_address[0])
		# nākamā atmiņas gabalā atrodas kontroles zīmes, p zīme palīdz noteikt vai iepriekšējais gabals tiek iedalīts programmai
		set $next_chunk =  $heap_pointer + (($heap_pointer[1] & ~7)/4)
		set $x = 0
		if (($next_chunk[1] & 1) == 1)
			set $malloc_pointer = $heap_pointer + 2

			reverse $malloc_pointer
			# adresēm priekšā var būt nulles, kuras var tikt pazaudētas
			count_zero $malloc_pointer
			# notiek meklēšana, ņemot vērā priekšējās nulles
			eval "shell cat gdb.core | egrep [0]{%x}%x > gdb.log", $zero, $addr
			shell echo set \$x=\"$(cat gdb.log)\" > gdb.log
			source gdb.log

			if (sizeof($x) < 8) 
				set $unref = $unref + 1
			end
			# komanda izdzēš .log datnes saturu
			shell > gdb.log
		end
		# kārtējais gabals ir apstrādāts, ir nepieciešams pārvietot kaudzes norādi
		set $heap_pointer =  $heap_pointer + (($heap_pointer[1] & ~7)/4)
	end
	shell rm gdb.log
	printf "Procesa adrešu telpā nav atrastas %i norādes.", $unref	
end

# $arg0: galvenās arēnas adrese
# komanda saglabā atmiņas izmeti heksadecimālā formātā un izdzēš atstarpes, jo dati var nebūt izklidzināti
define analyze
	shell xxd core > gdb_tmp.core
	shell cat gdb_tmp.core | tr -d ' ' > gdb.core
	shell rm gdb_tmp.core
	get_alloc_chunk $arg0
end