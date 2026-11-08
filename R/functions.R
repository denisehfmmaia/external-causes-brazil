# =============================================================================
# functions.R
# Functions used by more than one script. Loaded by 00_setup.R.
# =============================================================================


# -----------------------------------------------------------------------------
# age_to_group(): converts age labels to the 19 age groups in `ages`
#   Works with labels such as 0, 1, 5, "1-4", "Menor 1 ano", "85 a 89", "90+".
#   Everything aged 85 or more goes to "85+".
#   Labels without a number (e.g. "Idade ignorada") become NA.
# -----------------------------------------------------------------------------
age_to_group <- function(x) {
  x <- as.character(x)

  # lower bound of the age group (first number in the label)
  lower <- suppressWarnings(as.numeric(str_extract(x, "\\d+")))
  lower[str_detect(x, regex("menor|<\\s*1", ignore_case = TRUE))] <- 0

  case_when(
    is.na(lower) ~ NA_character_,
    lower == 0   ~ "0",
    lower < 5    ~ "1-4",
    lower >= 85  ~ "85+",
    TRUE         ~ paste0(floor(lower / 5) * 5, "-", floor(lower / 5) * 5 + 4)
  )
}


# -----------------------------------------------------------------------------
# broad_age_group(): groups the 19 ages into wider groups for the figures
#   breaks = last age of each group, except the open one.
#   Default gives 0, 1-14, 15-44, 45-64, 65-79, 80+ (Figures 3 and 4).
# -----------------------------------------------------------------------------
broad_age_group <- function(age, breaks = c(0, 14, 44, 64, 79)) {
  lower  <- as.numeric(str_extract(age, "^\\d+"))
  starts <- c(0, head(breaks, -1) + 1)
  labels <- c(ifelse(starts == breaks, starts, paste0(starts, "-", breaks)),
              paste0(max(breaks) + 1, "+"))
  as.character(cut(lower, breaks = c(-Inf, breaks, Inf), labels = labels))
}


# -----------------------------------------------------------------------------
# classify_cause(): ICD-10 underlying cause -> cause group used in the article
#   icd  = code as in the SIM (e.g. "X954", "U071")
#   year = year of death (COVID-19 codes are only accepted from 2020 onwards)
#
# The ORDER of the lines matters: each death goes to the FIRST group whose
# condition is TRUE. For example, J40-J47 (COPD) is checked before the
# "avoidable" group, which also contains J20-J99.
# -----------------------------------------------------------------------------
classify_cause <- function(icd, year) {
  c3 <- substr(icd, 1, 3)                       # 3-character ICD code
  is_between <- function(a, b) c3 >= a & c3 <= b # alphabetical comparison works for ICD-10

  covid_codes <- c("B342", "U071", "U072", "M303", "U109")

  avoidable_single <- c("A33", "A34", "A35", "A36", "A37", "A80", "B05", "B90",
                        "C44", "C50", "C53", "C54", "C55", "C62", "C81",
                        "I15", "N40")
  is_avoidable <- c3 %in% avoidable_single |
    is_between("A00", "A09") | is_between("A15", "A19") | is_between("A40", "A41") |
    is_between("C18", "C21") | is_between("C91", "C95") | is_between("E00", "E07") |
    is_between("G40", "G41") | is_between("I05", "I09") | is_between("I10", "I13") |
    is_between("J00", "J08") | is_between("J20", "J99") | is_between("K25", "K27") |
    is_between("K35", "K38") | is_between("K40", "K46") | is_between("K80", "K81") |
    is_between("N00", "N07") | is_between("N17", "N19") | is_between("N25", "N27") |
    is_between("O00", "O99") | is_between("P00", "P96") | is_between("Q20", "Q28") |
    is_between("Y60", "Y69") | is_between("Y83", "Y84")

  case_when(
    icd %in% covid_codes & year >= 2020                 ~ "covid19",
    is_between("X60", "X84")                            ~ "suicide",
    is_between("X85", "Y09")                            ~ "homicide",   # Y35-Y36 (legal intervention) NOT included
    is_between("V01", "V99")                            ~ "transport",
    is_between("I20", "I25") | is_between("I60", "I69") ~ "cardiovascular",
    is_between("E10", "E14")                            ~ "diabetes",
    is_between("C33", "C34")                            ~ "lung_cancer",
    is_between("J40", "J47")                            ~ "copd",
    is_between("J09", "J18")                            ~ "influenza_pneumonia",
    is_avoidable                                        ~ "avoidable",
    is_between("W00", "Y89")                            ~ "other_external", # rest of ICD chapter XX
    TRUE                                                ~ "other"           # includes R00-R99 (ill-defined)
  )
}


# -----------------------------------------------------------------------------
# life_table(): builds a life table from age-specific death rates
#   mx = death rates for the 19 age groups
#   n  = width of each age group (NA for the open group)
#   ax = average years lived in the age group by those who die in it
# Returns a data frame with lx, dx, Lx, Tx and ex (radix l(0) = 1).
# -----------------------------------------------------------------------------
life_table <- function(mx, n = age_width, ax) {
  k  <- length(mx)
  mx <- pmax(mx, .Machine$double.eps)   # avoids division by zero when a rate is 0

  # probability of dying in the age group (1 in the open age group)
  qx <- n * mx / (1 + (n - ax) * mx)
  qx[is.na(n)] <- 1
  qx <- pmin(pmax(qx, 0), 1)

  lx <- numeric(k)
  dx <- numeric(k)
  Lx <- numeric(k)
  lx[1] <- 1

  for (i in 1:k) {
    dx[i] <- lx[i] * qx[i]
    if (is.na(n[i])) {                         # open age group
      Lx[i] <- lx[i] / mx[i]
    } else {
      Lx[i] <- n[i] * (lx[i] - dx[i]) + ax[i] * dx[i]
      if (i < k) lx[i + 1] <- lx[i] - dx[i]
    }
  }

  Tx <- rev(cumsum(rev(Lx)))
  ex <- Tx / pmax(lx, .Machine$double.eps)

  # A list is used instead of a data frame because this function is called
  # millions of times by horiuchi(), and lists are much faster to create.
  list(mx = mx, qx = qx, lx = lx, dx = dx, Lx = Lx, Tx = Tx, ex = ex)
}


# -----------------------------------------------------------------------------
# Indicators as a function of the cause-specific rates.
# horiuchi() needs a function that receives ONE vector of parameters.
# Our vector is the matrix m(x, c) (ages in rows, causes in columns)
# stacked column by column, so the first step rebuilds the matrix.
# -----------------------------------------------------------------------------

# Life expectancy at birth, e(0)
e0_from_rates <- function(rates, ax) {
  m  <- matrix(rates, nrow = length(ages))
  lt <- life_table(rowSums(m), ax = ax)       # all-cause rate = sum over causes
  lt$ex[1]
}

# Life disparity, e-dagger = sum of d(x) * e(x)   (Vaupel et al. 2011)
edagger_from_rates <- function(rates, ax) {
  m  <- matrix(rates, nrow = length(ages))
  lt <- life_table(rowSums(m), ax = ax)
  sum(lt$dx * lt$ex)
}


# -----------------------------------------------------------------------------
# life_table_many(): e(0) and e-dagger for MANY sets of death rates at once
#   M = matrix of all-cause death rates: 19 rows (ages), one column per life table
#   Same arithmetic as life_table(), applied to all columns together.
# -----------------------------------------------------------------------------
life_table_many <- function(M, n = age_width, ax) {
  k  <- nrow(M)
  M  <- pmax(M, .Machine$double.eps)
  qx <- (n * M) / (1 + (n - ax) * M)       # n and ax are recycled down each column
  qx[k, ] <- 1                             # open age group
  qx <- pmin(pmax(qx, 0), 1)

  lx <- dx <- Lx <- matrix(0, k, ncol(M))
  lx[1, ] <- 1
  for (i in 1:k) {
    dx[i, ] <- lx[i, ] * qx[i, ]
    if (i < k) {
      Lx[i, ]     <- n[i] * (lx[i, ] - dx[i, ]) + ax[i] * dx[i, ]
      lx[i + 1, ] <- lx[i, ] - dx[i, ]
    } else {
      Lx[i, ] <- lx[i, ] / M[i, ]
    }
  }
  Tx <- Lx
  for (i in (k - 1):1) Tx[i, ] <- Tx[i + 1, ] + Lx[i, ]
  ex <- Tx / pmax(lx, .Machine$double.eps)

  list(e0 = ex[1, ], edagger = colSums(dx * ex))
}


# -----------------------------------------------------------------------------
# decompose_both(): Horiuchi et al. (2008) decomposition of the change in e(0)
#   AND in e-dagger between two matrices of cause-specific rates m(x, c)
#   (ages in rows, causes in columns), with N steps.
#
#   Gives the same numbers as DemoDecomp::horiuchi() applied to e0_from_rates()
#   and edagger_from_rates() (differences of the order of 1e-13), but computes
#   all the perturbed life tables in one go with life_table_many(), and both
#   indicators from the same life tables. About 14 times faster, which matters
#   in 07_uncertainty.R, where the decomposition is repeated thousands of times.
#
#   Returns a list of two matrices (ages x causes): $e0 and $edagger.
# -----------------------------------------------------------------------------
decompose_both <- function(m1, m2, N = n_horiuchi, ax) {
  k <- nrow(m1)
  C <- ncol(m1)
  d     <- m2 - m1
  delta <- d / N

  # all-cause rate at the middle of each of the N steps (k x N)
  total <- sapply(1:N, function(j) rowSums(m1 + d * (j - 0.5) / N))

  # one column for every (age a, cause c, step j): the all-cause rates of step j
  # with the rate of age a moved by +delta[a, c]/2 (and, below, by -delta[a, c]/2)
  grid  <- expand.grid(a = 1:k, c = 1:C, j = 1:N)
  cells <- cbind(grid$a, seq_len(nrow(grid)))
  shift <- delta[cbind(grid$a, grid$c)] / 2
  plus  <- total[, grid$j]; plus[cells]  <- plus[cells]  + shift
  minus <- total[, grid$j]; minus[cells] <- minus[cells] - shift

  up   <- life_table_many(plus,  ax = ax)
  down <- life_table_many(minus, ax = ax)

  # sum of the N steps for each (age, cause)
  by_cell <- function(v) matrix(rowsum(v, group = (grid$c - 1) * k + grid$a), k, C)
  list(e0      = by_cell(up$e0      - down$e0),
       edagger = by_cell(up$edagger - down$edagger))
}


# -----------------------------------------------------------------------------
# fix_ax(): fills missing ax values
#   age 0 without ax -> 0.3 ; other ages without ax -> half of the age width
# -----------------------------------------------------------------------------
fix_ax <- function(ax) {
  if (is.na(ax[1])) ax[1] <- 0.3
  missing <- is.na(ax)
  ax[missing] <- age_width[missing] / 2
  ax
}
