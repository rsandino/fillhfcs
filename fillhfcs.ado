*! version 1.0.0 Rosemarie Sandino 12jun2018

program fillhfcs
	syntax using/, survey(str) [Other(real -222)] [REFuse(real -888)] [DONTknow(real -999)] ///
	[OUTlier] [ENUMdb] [RESearch] [SPECify]

version 13
preserve
qui {
*******************************Outlier sheet************************************
if !mi("`outlier'") {
	noi dis "Filling in outliers sheet..."
	import excel using "`survey'", clear first
	keep if type == "integer" | type == "decimal" | regexm(type, "repeat")
	if `=_N' > 0 {
		repgroup 
		gen y = 3
		drop if regexm(type, "repeat")

		export excel name y using "`using'", sheet("11. outliers", modify) cell(A2)
	}

	else noi dis "No numeric variables found in this survey."

}

**********************************enumdb****************************************
if !mi("`enumdb'") {
	noi dis "Filling in enumerator dashboard..."
	*Find those that have don't know/refuse
	import excel using "`survey'", clear first sheet("choices")
	
	destring value, force replace
	keep if value == `refuse' | value == `dontknow'
	if `=_N' > 0 {
	
		levelsof list_name, local(choices)

		import excel using "`survey'", clear first
		split type, p(" ")
		drop type1
		gen dkrf = .

		*vars with choices that include dk/refuse
		foreach choice in `choices' {
			replace dkrf = 1 if type2 == "`choice'"
		}

		*numeric vars with dk/refuse
		replace dkrf = 2 if regexm(constraint, ".=`refuse'") | regexm(constraint, ".=`dontknow'")

		repgroup 
		keep if !mi(dkrf)
		keep name
	}
	else {
		dis "No missing or don't know options found in this survey."
		clear
		set obs 3
		gen name = ""
	}
		*sheet default formatting

		gen missing = ""
		gen duration = "duration" if _n == 1
		gen exclude = ""
			replace exclude = "starttime" if _n == 1
			replace exclude = "endtime" if _n == 2
			replace exclude = "formdef_version" if _n == 3
		gen sub = "submissiondate" if _n == 1

		export excel using "`using'", sheet("enumdb", modify) cell(A2)

}
**************************research oneway***************************************
if !mi("`research'") {
	noi dis "Filling in research oneway sheet..."
	import excel using "`survey'", clear first

	repgroup

	keep if type == "integer" | type == "decimal" | regexm(type, "select_one") 
	if `=_N' > 0 {
	keep type name x
	gen category = cond(type == "integer" | type == "decimal", "cont", cond(regexm(type, "yesno")|regexm(type, "yn"), "bin", "cat"))

	*Common things you don't want in the research tab
	drop if regexm(type, "name") | regexm(type, "id") | regexm(type, "team")

	export excel name category using "`using'", sheet("research oneway", modify) cell(A2)
	}

	else noi dis "No numeric, binary, or categorical variables found in this survey."
}
***********************Specify other********************************************
if !mi("`specify'") {
	noi dis "Filling in specify others sheet..."
	import excel using "`survey'", clear first

	keep type name label relevance

	gen child1 = ""
	gen parent1 = ""
	forval i = 1/`=_N' {
		if regexm(relevance[`i'], "`other'") {
			replace child1 = name[`i'] if _n == `i'
			local val = `i' - 1 
			replace parent1 = name[`val'] if _n == `i'
		}
			
	 }

	*Make repeated values show up for those in repeat groups
	keep if !mi(child1) | regexm(type, "repeat") 

	if `=_N' > 0 {

	repgroup other

	keep child1 parent1 x
	drop if mi(child1)
	
	levelsof parent1 if x > 0, local(repeats)

	forval i = 2/3 {
		cap gen child`i' = ""
		cap gen parent`i' = ""
		foreach rep in `repeats' {
			replace child`i' = child1 + "_`i'" if x > 0
			replace parent`i' = parent1 + "_`i'" if x > 0
			}

	}
	replace child1 = child1 + "_1" if x > 0
	replace parent1 = parent1 + "_1" if x > 0


	**Adding nested repeats, but only 1 repeat
	sum x
	forval i = 2/`r(max)' {
		forval j = 1/3 {
			replace child`j' = child`j' + "_1" if x == `i' & !mi(child`j')
			replace parent`j' = parent`j' + "_1" if x == `i' & !mi(parent`j')
		}
	}
		
	drop x
	gen n = _n, before(child1)

	reshape long parent child, i(n)

	export excel child parent using "`using'" if !mi(child), sheet("9. specify", modify) cell(A2)
	}

	else noi dis "No 'specify other' questions found in this survey."
	}

}
restore
end

program repgroup
	gen x = .
	loc y 0
	forval i = 1/`=_N' {
		if type[`i'] == "begin repeat" {
			loc y `++y'
		} 
		if type[`i'] == "end repeat" {
			local y `--y'
		}
			replace x = `y' if _n == `i'
	}

	if mi("`0'") {
		replace name = name + "_*" if x == 1
	}
end

